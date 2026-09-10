# Web 使用量统计：数据库变更审阅稿

状态：设计待确认，尚未新增 migration、修改数据库或接入线上统计。对应改善计划 T06／W07。现有模型、声线与额度不变。

## 原本与修改后

| 项目 | 原本 | 修改后 |
| --- | --- | --- |
| 计数单位 | `usage_records` 每次额度认领记 `estimated_units = 1` | 保留额度表；另按一次实际供应商请求记录一条 attempt |
| 批量生成 | 一个批次有多个句子额度记录，不能代表模型调用数 | 一批只记一次供应商 attempt，并记录 `item_count`；不把总 tokens 重复算给每句 |
| 转写／整理 | 共用 `capture_preparation` 额度 | 统计功能分开，额度仍共用原来的每分钟 2 次／每日 10 次 |
| 使用量 | 没有实际 tokens 或字符、时长记录 | 保存供应商报告的用量，字符和客户端时长注明来源；拿不到时为 `null` |
| 费用 | 无可复算的实际使用量估算 | 保存价格版本和估算依据，估算金额与账单金额区分 |
| 失败 | 业务请求失败或释放额度 | 单独区分供应商失败、供应商成功但交付失败、结果未知；释放本地额度不视为退款 |
| 隐私 | 学习事件不允许任意自由文本 | 费用记录仅接收白名单数字、固定枚举和系统 ID，不保存句子、录音、凭据或供应商原始错误 |

## 最小数据结构

拟新增 `public.generation_usage_attempts`；下一 migration 文件名为 `005_generation_usage.sql`，实施前再次确认编号未占用。

| 字段 | 类型／约束 | 用途 |
| --- | --- | --- |
| `id` | UUID，主键 | 在发起一次供应商请求前创建；同一次记录重写沿用此 ID |
| `user_id` | UUID，外键 `auth.users` | 隔离账户；账户删除时级联删除 |
| `client_request_id` | UUID | 关联已通过现有额度认领的业务请求 |
| `feature` | 固定枚举：`transcription`、`sentence`、`preparation`、`batch`、`tts` | 区分功能，不改变 `generation_requests.operation_type` |
| `model` | 服务端固定模型值 | 不接收客户端任意模型名 |
| `provider_request_id` | 可空且有长度上限的 string | 仅从供应商响应头 `x-request-id` 提取，便于账单核对 |
| `started_at`、`finished_at` | timestamptz；结束可空 | 请求开始和结束时间 |
| `provider_status` | `started`、`succeeded`、`failed`、`unknown` | 断网、超时或进程终止后使用量可能未知 |
| `delivery_status` | `pending`、`succeeded`、`failed` | 上游成功不等于 Storage／数据库／客户端交付成功 |
| `http_status` | 可空 integer，100—599 | 不保存上游原始响应体 |
| `error_code` | 服务端固定错误枚举，可空 | 禁止直接写 `error.message` |
| `item_count` | integer，1—20 | 仅作业务数量；批量 tokens 不据此复制 |
| `input_tokens`、`cached_input_tokens`、`output_tokens` | 可空非负 bigint | 文本供应商实际 usage；cached 为 input 子集 |
| `audio_input_tokens`、`text_input_tokens` | 可空非负 bigint | 转写混合 token 分量；未报告时保持未知 |
| `input_characters` | 可空非负 integer | TTS 输入的 Unicode 字符数，标为请求推导值 |
| `duration_ms` | 可空正 integer | 转写请求时长，标为客户端报告；不冒充供应商精确时长 |
| `usage_source` | `provider`、`request_estimate`、`unknown` | 区分实报与推算 |
| `price_version` | 固定版本字符串，可空 | 例如 `openai-standard-2026-09-08`；上线前重新核实对应价格 |
| `estimate_basis` | `text_tokens`、`tts_characters`、`transcription_duration`、`unknown` | 可复算口径 |
| `estimated_cost_usd` | 可空 `numeric(16,10)`，非负 | 未知是 `null`；不代表已结算账单 |

保留 `generation_requests` 与 `usage_records` 的原结构、索引、认领逻辑及限额。新表启用 RLS，并撤销 `anon`／`authenticated` 的读写权限，仅 service role 使用受控写入／汇总接口。按 `(user_id, started_at)` 建索引；默认从服务端按功能、模型和日期聚合，不增加 Web 费用页面。

## 写入与重试顺序

1. 完成鉴权、输入校验和原有额度／内容认领。命中句子、Storage、幂等重放或正在生成时，不创建供应商 attempt。
2. 真正要发送 `fetch` 前写一条 `started`。写入失败则返回可重试的统计服务错误并释放本次业务认领；不发起无法登记的付费调用。此行为在接入测试中单独验证。
3. 发起一次供应商请求。请求失败、超时、返回无效 JSON 仍更新这条 attempt，不能因此删除统计记录；解析教学内容前先提取响应中的 usage。
4. 供应商成功后只重试 Storage 上传、清单更新或签名时，沿用该 attempt，不新增供应商计数。
5. 完成写入可按 attempt ID 幂等重试，最多 3 次；仍失败保留 `started`，后续受控查询标为未完成／用量未知。不将旧 `started` 自动认定为零消耗或失败未扣费。
6. 用户明确重试且确实重新发起供应商请求时创建新 attempt。同一业务 request ID 可有多次 attempt；唯一性放在 attempt ID 上，不对业务 ID 设置唯一约束。

分段请求 ID 已在现有接口内逐段保存，费用表不需复制原文或建立新的业务队列。跨设备生成来源持久化若后续需要，另列句子表变更，不混入本次费用表。

## 费用口径与验证

价格依据沿用[费用调研档案](2026-09-07-web-ai-cost-research.md) 的有日期快照。正式启用前重新核对官方价格并固定版本；不回写历史估算来冒充历史账单。

- 文本：`((input_tokens - cached_input_tokens) × 输入单价 + cached_input_tokens × 缓存输入单价 + output_tokens × 输出单价) / 1,000,000`。cached 未报告或分量不完整时，按普通输入价计算的金额必须标明上界估算，不能假装精确。
- TTS：按输入字符量和 `tts-1` 字符单价估算。只有已明确供应商成功的请求才把字符推导值作为费用估算；失败／超时可能仍计费时，金额保持未知。
- 转写：客户端录音时长只能结合官方分钟估计给出预算估算。实际 token 分量完整且对应价格核实后才能按 token 计算；禁止把音频和文本 tokens 乘同一单价。
- 汇总同时显示 attempt 总数、已知使用量数、未知次数、已知估算金额，不能仅展示金额而隐去缺失使用量。

必要验证：缓存／重放 0 次；一批五句 1 次；供应商失败和超时各 1 次；上传三次仍 1 次；真实重新生成增加 attempt；重复完成写入不增加行；cached tokens 不重复计价；未知不归零；匿名与普通账户不可访问；原额度、RLS 和并发测试保持通过。数据库验证仅在批准后的隔离数据库运行。

## 确认范围与部署顺序

建议先批准本地 migration、统计模块与替身／隔离数据库测试的实施，审阅通过后再单独批准远端 migration 与相关函数部署。数据库 schema 尚未获准；真实样本按后续已确认的 T09 预算执行，其实际验收状态以 ROADMAP 为准。

新增表会增加一次调用的开始／结束写入开销；开始写入失败会暂时阻止新付费请求。恢复时先切回当前不依赖统计表的函数构建，保留统计表与已有数据，不用删除数据作为回退手段。远端发布前需确认项目 `ijonabyyppmgvoufgamt`、数据库备份、顺序和监控结果。
