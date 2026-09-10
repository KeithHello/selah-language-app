# Selah Web 改善实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 状态：2026-09-09 已完成本地核心改善、自动化验证与 Release 候选；`speech-transcribe` 和四个生成／音频函数已部署。真实样本、数据库用量统计、真机和 Web 公开发布仍未完成。验收证据见 [Web 改善验收](../../web-improvement-acceptance-2026-09-09.md) 。
>
> **Goal:** 保留现有语音与生成服务，补齐 Web 输入恢复、长文本处理、重试与费用观测，完成真实服务、设备和发布验收。
>
> **Architecture:** 沿用现有 Flutter Web 页面、LearningController、本地账户快照及 Supabase Edge Functions；优先补齐现有边界，只有实际数据职责需要时才新增小型模块。
>
> **Tech Stack:** Flutter／Dart、浏览器 MediaRecorder／IndexedDB／Service Worker、Supabase Auth／Postgres／Storage／Deno、现有 OpenAI API。

## Global Constraints

- 主人已经确认保留 `gpt-4o-mini-transcribe`、`gpt-4o-mini`、`tts-1`，以及现有声线映射、0.85 生成速度、MP3、Storage 和音频缓存。替代供应商不在本计划内。
- 2026-09-08 起主人已授权本计划的 Web 实施、验证与候选构建；2026-09-09 已单独确认并执行 `speech-transcribe` 部署，30 句语音范围扩展为现有四种声线共 120 段。数据库、其他函数部署与 Web 公开发布仍按各自边界确认。
- 范围仅含 Web 及其共用服务的必要兼容改动；原生客户端、角色重新设计和 Web Push 不纳入本轮核心完成条件。
- 开始实施前重新阅读根目录与 `SelahFlutter/CLAUDE.md`、`ROADMAP.md`，检查工作区已有改动。不得覆盖其他未提交工作。
- 数据库 schema／migration、密钥与环境文件、CI/CD 配置、外部发布依照项目红线单独确认；真实付费样本依照 [语音服务约定](../../web-speech-service.md) 和已确认预算执行，不扩大调用次数。
- 现有共享额度先维持原值；不得因区分转写与整理的统计而自动扩大用户可消费额度。
- 测试优先验证可见结果、数据完整性和供应商实际调用次数。测试替身与静态合约通过不代表真实服务或真机验收完成。
- 只有代码与对应验证均完成才勾选开发任务；提交、删除、远端迁移和发布均不得隐含在“收尾”中。

## 依据与交付关系

- [费用调研档案](../../2026-09-07-web-ai-cost-research.md) ：保留决策、官方价格、测算假设与费用节约方法。
- [逐项改善设计](../specs/2026-09-07-selah-web-improvement-design.md) ：W01—W13 的原本行为、修改后行为与验收条件。
- [真实进度源](../../../ROADMAP.md) ：按实际证据更新状态；本计划不覆盖旧日期的历史验证结果。
- 当前正式页面为 `SelahFlutter/lib/web/ui/web_learning_app.dart`。控制器已有能力是否真正进入页面，必须通过正式入口验证。
- 现有五十张 RGBA 运行素材已完成处理，不再列为需要重新生成的工作。后续只测量设备表现，再决定是否需要更小的发布尺寸。

## 执行次序与依赖

| 阶段 | 任务 | 开始条件与产出 |
| --- | --- | --- |
| 第一批：修复核心链路 | T01、T02；同时准备 T07 的最小变更包，执行 T09 中不产生费用的账户验证 | 优先解决输入丢失风险、超过五段无法继续以及转写接口不可用；配置、部署与真实调用分别遵守确认边界 |
| 第二批：减少重复调用 | T03 → T04；T05 | 统一输出契约后引入可验证的生成来源；复用已有句子，修复音频卡住和可恢复的存储失败 |
| 第三批：观测与完整内容 | T06、T08 | 费用表结构需独立确认；默认种子音频优先取回现有文件，不重新生成 |
| 第四批：端到端与设备验收 | 完成 T09，再执行 T10 | 使用已确认的测试账户、调用预算与设备环境，记录结果和失败路径 |
| 发布准备 | T11 | 汇总前述证据并生成可审阅的发布候选；公开部署为最后的独立确认步骤 |
| 暂缓增强 | T12 | 仅在明确需要关闭网页后的提醒时，另行启动 |

T07 与 T09 属于 P0，编号靠后仅为按工作领域归档，不表示等所有 P1 优化结束才恢复转写或检查普通用户权限。T06 不是首轮联调的强制依赖：未建立统计前，采用明确数量的测试调用上限。

## T01：正式页面接入输入草稿与异步保护（W02，P0）

**修改文件：** `SelahFlutter/lib/web/ui/web_learning_app.dart`、`SelahFlutter/lib/web/learning_controller.dart`、`SelahFlutter/test/web_reliability_controller_test.dart`。
**新增文件：** `SelahFlutter/test/web_generation_ui_test.dart`，用于正式页面交互回归；实施前检查是否已有同职责文件，避免重复。

- [x] 先通过正式入口复现：输入后重建页面是否恢复；提交 A 后在等待期间改成 B，A 成功时 B 是否被清空。保留失败测试结果，不把静态疑点直接写成已复现。
- [x] 初始化输入框时恢复当前账户快照，输入变化调用已有 `updateTodayInput`；处理控制器监听与文本框同步，防止光标跳动、重复写入和输入法组合文字被覆盖。
- [x] 请求提交时记录输入版本。只有“账户一致、仍为提交版本且结果已保存”才清理该草稿；用户后续编辑、切换账户或错误返回时保留对应账户状态。
- [x] 分段编辑接入已有持久化入口，并为 T02 的扩容保留单一状态来源，避免页面和控制器各存一份互相覆盖的草稿。
- [x] 验证刷新恢复、A／B 异步竞争、失败重试、退出登录与账户切换；验证已有转写插入、显式替换和撤销仍成立。空分句会在请求前阻止并提示补全。

**完成证据：** 正式页面回归与控制器测试通过；使用浏览器实际输入并刷新一次。不得仅凭控制器单测宣称页面已接线。

## T02：完整保留长文本并按五句分批生成（W03、W04，P0／P1）

**依赖：** T01 的输入版本与账户保护。
**修改文件：** `SelahFlutter/lib/web/domain/learning_models.dart`、`SelahFlutter/lib/web/learning_controller.dart`、`SelahFlutter/lib/web/ui/web_learning_app.dart`、`SelahFlutter/test/web_models_test.dart`、`SelahFlutter/test/web_controller_test.dart`、T01 的页面测试。
**可新增文件：** `SelahFlutter/lib/web/domain/generation_workflow.dart` 及 `SelahFlutter/test/web_generation_workflow_test.dart`，仅在需要独立承载纯分批和任务恢复逻辑时创建。

- [x] 建立边界用例：整理结果为 1、5、6、20、21 段；当前服务上限为 20，21 段应明确报错并保留原文，不能截掉后面的内容。
- [x] 将本地快照扩展为可选 `preparationDraft`，保存整理 request ID、输入版本、语言、完整结果和各段的稳定 ID、顺序、文本及状态；兼容现有 version 1 备份与缺省字段。
- [x] 在请求前持久化整理 request ID；同一输入的超时重试复用 ID，编辑原文后使用新 ID。成功后先保存完整整理结果，再进入编辑界面。
- [x] 对齐控制器的 `mapList(max: 5)`、页面 `take(5)` 和备份恢复 `take(5)` 等边界，使准备／编辑最多保留 20 段；单次生成接口仍限制 5 段。
- [x] 顺序提交不超过 5 段的批次；每段保持稳定 ID。每批成功就保存结果，后批失败只保留失败／未提交段待重试，页面显示已完成与剩余数量。
- [x] 不重写已有批量接口的逐段幂等机制；验证同一段重试不会重复生成，已经成功的段不会再次进入待生成集合。
- [x] 验证第二批失败、请求超时后恢复、关闭页面重开、编辑单段、账户切换、旧备份导入；确认 20 段的顺序和文本完整。

**完成证据：** 六段和二十段均可完整生成，失败后只重试剩余段；无静默丢弃，且供应商替身调用数符合分批数量。

## T03：统一生成输出与来源信息（W06，P1）

**修改文件：** `supabase/functions/_shared/sentence_contract.ts`、`supabase/functions/_shared/capture_contract.ts`、`supabase/functions/sentences-generate/index.ts`、`supabase/functions/sentences-prepare/index.ts`、`supabase/functions/sentences-batch-generate/index.ts`、对应 `sentences_generate_test.ts`／`capture_contract_test.ts`；Web 的 `learning_models.dart`、`learning_controller.dart` 与模型测试。

- [x] 先列出三种响应的必需字段、最大输入与输出长度、分类范围、分段 ID 完整性及异常处理，保持既有成功响应字段兼容。
- [x] 修正单句“词汇 2—4 个”与“最多 3 个”的冲突，统一为最多 3 个；英文必须非空且不超过现有 1,000 字符上限，分类限既有六类。
- [x] 给单句、整理、批量请求分别加入明确输出预算。初始评估值为 2,048／4,096／8,192 output tokens；这三个值不是已验证的生产阈值。
- [x] 使用 500 字符单句、20 段整理、5 句批量等有效上界样本检查预算；若合法完整结果被截断，调整预算再验证，不能靠删内容让测试通过。
- [x] 明确处理 `finish_reason=length`、缺失字段、非法分类、JSON 不完整、重复／遗漏分段 ID；失败时保留输入与待办，不自动进行无上限的再次生成。
- [x] 响应与本地句子增加可选生成模型、prompt 版本、源语言及目标语言来源信息；旧快照缺省时保留“未知”，不推断旧内容一定来自当前模型。
- [x] 共用服务保持既有字段兼容。来源信息跨设备持久保存仍需单列数据库变更，本轮未扩展表结构。

**完成证据：** 有效与无效响应合约测试通过；实际质量和真实 token 消耗在批准的 T09 样本中确认。模型、声线均不变。

## T04：复用已经生成的相同句子（W05，P1）

**依赖：** T01、T03。
**修改文件：** `SelahFlutter/lib/web/learning_controller.dart`、`SelahFlutter/lib/web/ui/web_learning_app.dart`、`SelahFlutter/test/web_controller_test.dart`、T01 的页面测试。

- [x] 定义保守匹配规则：当前账户、相同源／目标语言、已知且一致的模型与 prompt 版本，以及仅修剪首尾空白和统一换行后的中文原文。
- [x] 对匹配到的已完成句子直接打开现有学习条目，保留原句 ID、掌握度、复习进度和音频引用，供应商调用次数为零。
- [x] 旧数据缺少来源时只提示“已有相同内容，可打开”，不自动认定为可复用结果；不得跨账户、跨版本或按模糊语义合并。
- [x] 提供明确的“重新生成”操作，创建新请求 ID；普通网络重试继续复用原 ID，两者行为区分清楚。
- [x] 验证相同输入重复提交、语言／版本变化、旧内容、账户切换和主动重新生成；已有学习记录不会被重置。

**完成证据：** 页面可复用已有条目，测试能够断言命中时不调用生成接口；主动重新生成路径仍可用。

## T05：修复音频长时间等待与可恢复失败（W08，P1）

**修改文件：** `supabase/functions/_shared/audio_generation_policy.ts`、`supabase/functions/audio-generate/index.ts`、`supabase/tests/audio_generate_test.ts`、`supabase/tests/audio_delivery_test.ts`；如响应状态需要调整，同步 Web 控制器及其测试。

- [x] 建立真实处理顺序的替身测试：生成中且未过期、过期状态、供应商成功但上传失败、对象已存在但清单未 ready、签名失败、两个并发重试。
- [x] 利用现有 `audio_manifests.updated_at` 与生成账本，区分有效进行中和过期任务；采用带旧状态／时间条件的原子认领，认领失败的请求不得调用 TTS。
- [x] 将供应商请求超时、任务有效期和客户端轮询上限对齐，避免永久返回 202；现有字段足以表达本轮恢复状态，未新增 migration。
- [x] 重试前检查对应 Storage 对象及内容标识；已有可验证文件时补齐清单／重新签名后返回，不再次生成。
- [x] 当前请求仍持有 MP3 数据时，只对上传做有界重试；清单更新失败保留可恢复路径。固定的恢复重试不能触发无限供应商调用。
- [x] 保持内容哈希、当前声线、速度、模型、音频格式和账户隔离；不承诺供应商响应丢失且文件从未保存时能够严格只计费一次。

**完成证据：** 卡住的状态有明确出口，已有对象的恢复路径 TTS 调用为零，并发恢复最多由一个有效认领者发起新生成。

## T06：记录真实使用量并区分费用估算（W07，P1）

**依赖：** 已确认指标口径；数据库变更需独立确认。
**拟新增文件：** `supabase/functions/_shared/generation_usage_contract.ts`、`supabase/tests/generation_usage_test.ts`；确认后才能新增 `supabase/migrations/005_generation_usage.sql`，如编号已被占用则使用下一可用编号。
**修改文件：** 三个文本函数、`speech-transcribe/index.ts`、`audio-generate/index.ts`、相关数据库测试。当前仅计划，不创建这些代码或 SQL。

- [x] 最小统计数据设计已归档于 [使用量统计设计](../../2026-09-08-generation-usage-design.md) ：以供应商调用 attempt 为一条记录，关联业务 request ID、功能类型、模型、供应商 request ID、实际 tokens／字符／时长、成功状态及使用量是否已知；此项仅完成设计，尚未创建 schema 或统计代码。
- [ ] 将统计记录与现有 `usage_records` 的限额职责分开；一次批量供应商调用只记一次消耗，逐句分摊若需要必须另标为分配值。
- [ ] 记录单价版本与估算金额，区分供应商报告的 usage、由字符／时长推导的估算和未知。未知不是零；不能把本地释放额度说成供应商退款。
- [ ] 文本 cached tokens 是输入 tokens 的子集，不重复计算；转写分钟价格为官方估计，不把所有类型 audio tokens 都套用同一公式。
- [ ] 指标只保存必要元数据，不把原始录音、全文或密钥写进费用日志。保留现有每日／每分钟限制，统计拆分不能自动扩大额度。
- [ ] 覆盖缓存命中、失败、超时、重试和一批多句的计数测试；只记录实际发生的 attempt，不把被幂等拦住的请求记成供应商调用。
- [ ] 先用服务端受控查询提供汇总，确认数据可靠后再决定是否增加费用页面或新的金额硬上限；不在本任务扩展产品界面。

**完成证据：** 按功能／模型查看调用数、已知使用量与未知次数，估算可复算；已有额度与账户权限测试仍通过。

## T07：补齐转写注册并恢复真实链路（W01，P0）

**修改文件：** `supabase/config.toml`、`supabase/tests/deployment_contract_test.ts`、`supabase/tests/speech_transcribe_test.ts`、`docs/web-speech-service.md`；部署脚本仅在明确需要且配置确认后修改。

- [x] 先确认目标项目、函数名称、当前 HTTP 状态与本地处理器版本。2026-09-09 无凭证 `OPTIONS`／`POST` 均返回 404，仅说明当前远端路由不可用，不能推断模型或密钥也有问题。
- [x] 准备仅补齐 `speech-transcribe` 注册的配置差异和部署合约测试；逐字段对照处理器需要的鉴权、multipart 字段、中文语言设置、10 MiB／180 秒限制。
- [x] 确认配置改动后落实最小注册；本地测试覆盖无会话、无效文件、时长／大小超限、上游错误、稳定 request ID 重放和资源释放。
- [x] 准备单函数部署命令、目标项目与验证步骤，沿用已有 secret；主人确认后已执行单函数部署。
- [x] 不为补一个函数运行 `deploy-full.sh`：该脚本还会执行数据库、secret、多函数部署和种子导入，超出本任务范围；本地操作单已明确仅部署目标函数。
- [x] 确认后仅部署目标函数，已验证 `OPTIONS 200` 与无凭证 `POST 401 UNAUTHORIZED_NO_AUTH_HEADER`；部署辅助脚本的离线预演、CLI 登录兼容、固定项目目录和健康检查另有 6 项本地替身验证。
- [ ] 按已批准的调用预算，用普通测试账户提交一段中文录音并重放相同请求；当前缺普通账户与录音样本。
- [ ] 记录真实 HTTP、转写内容是否可用、重放是否复用及设备麦克风结果；日志隐去凭据与私人内容。失败保留原录音供当前会话重试。

**完成证据：** 真实录音返回可用中文文本，同一请求重放不重复调用上游；不能以 OPTIONS 200 或替身测试代替。

## T08：补齐 30 句四种声线的现有音频（W09，P1）

**修改文件：** `SelahFlutter/assets/content/seed-audio.json`、`SelahFlutter/assets/audio/` 内需要补入的 MP3、`SelahFlutter/web/selah_service_worker.js`、音频清单读取与对应测试；依照当前路径规则保存文件，不新建第二套缓存。

- [x] 读取并核对云端 30 句 × 4 声线的 120 条 ready 清单；历史计数没有替代当前文件有效性校验。
- [x] 取回当前缺少的四声线文件，对照句子 ID、声线、内容 hash、sha256 和字节数校验后补入本地包。
- [x] 对不存在或损坏的文件列出例外，不自动调用 `seed_audio_prebuild.ts` 重新生成；本轮新增 TTS 调用为 0。
- [x] 保留已存在音频，四种声线均进入实际预缓存列表与构建清单，避免资产已补入但离线缓存漏掉。
- [x] 120 段全部通过 SHA-256、字节数、本地与 Release 副本一致性及 FFmpeg 完整解码；Chrome 断网读取 120 段并校验哈希，四声线抽样解码通过；损坏缓存恢复由浏览器合约测试覆盖。Release 候选产物共 231 个文件、99,790,053 字节，其中 MP3 12,529,440 字节。

**完成证据：** 30 条种子每条均对应四种声线的真实文件与上述解码／离线证据，缺失和损坏为 0；本任务新增 TTS 调用为零。逐文件证据见 `output/playwright/final-web-acceptance/seed-audio-verification.json`。

## T09：普通用户与真实业务端到端验收（W10、W01，P0）

**依赖：** 账户权限可先验；完整语音流程依赖 T07，长文本恢复依赖 T02。
**修改文件：** `supabase/scripts/remote_acceptance.ts`、`supabase/tests/remote_acceptance_contract_test.ts`、`docs/web-acceptance.md`；必要时新增按实际执行日期命名的 Web 验收记录。

**当前缺口：** 普通账户与中文录音样本未配置；`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 已部署并完成源码核对，但仍需在普通账户真实样本中验收最新处理器。

- [x] 保留验收脚本默认 dry-run，不联网／不计费。执行开关与现有付费确认仍有效，不能因增加转写步骤默认发起真实请求。
- [x] 每轮创建独立 run ID，同轮重试保持稳定；避免永久固定 ID 命中旧结果，误报最新供应商路径已验证。
- [x] 将第二普通账户登录与已有句子／事件的 RLS 样本预检移到首次付费接口之前；账号或样本错误时不发起模型请求。新增 6 类失败回归与成功顺序检查，验收脚本共 22 项测试通过；新音频的隔离检查仍在生成后执行，未配置项保留 `not_configured`。
- [ ] 使用普通测试账户检查登录、恢复会话、写入和读取；两个账户验证互不可读写私人句子、事件与音频，两个设备验证同一账户状态合并。
- [x] 提前列出真实调用上限。dry-run 计划固定为 1 次转写、1 次单句、1 次整理、1 次五句以内批量、1 次单声线 TTS；重放与缓存验证不新增供应商调用，异常停止后再决定是否重试。
- [ ] 在已批准的预算内完成中文录音 → 文字确认 → 英文／拆解／词汇 → MP3 → 聆听记录 → 练习保存 → 笔记 → 跨设备恢复。
- [ ] 注入离线、上游超时、上传／签名失败、无效 JWT、限额触发与账户切换，区分可本地替身验证和必须远端验证的项目；不得用 service-role 查询代替 RLS 验收。
- [ ] 比对页面显示、数据库状态和费用记录；没有实际执行的项目保留“未验证”，写清依赖，不用成功计数掩盖失败步骤。

**完成证据：** 有日期、构建 ID、环境、普通账户角色、每一步结果、实际调用次数和异常路径的记录；真实付费样本质量另行标记。

## T10：真机、PWA 与性能验收（W11，发布前必需）

**修改文件：** `docs/web-acceptance.md`、`docs/web-plush-50-acceptance.md`；只有实测发现缺口时才修改相关 Web 代码、Service Worker 或生成更小尺寸运行素材。

- [x] 完成本地首装性能实测与对应优化：依据当前构建只启用 CanvasKit 的配置，移出 8 个未启用渲染器预缓存文件；缓存减少约 22.7％，两种 CanvasKit 的离线重开与 120 段音频校验通过。证据见 [首装性能验收](../../web-performance-2026-09-09.md) 。不替代下面的真机和生产网络项目。
- [ ] 使用实际 iPhone Safari／主屏幕 PWA、Android 浏览器和桌面浏览器，记录设备、系统、浏览器、构建 ID 与网络条件。
- [ ] 验证麦克风允许／拒绝、停止／取消、中文输入法与软键盘、窄屏操作、后台恢复、播放手势、网络切换、账户切换和存储被清理。
- [ ] 验证首次加载、已安装离线重开、升级提示、旧缓存切换与音频可用性；更新前存在未保存输入或练习时，提示与恢复行为须保留内容。生产 PWA 更新须在明确批准的环境验证。
- [ ] 测量首屏可操作时间、实际下载体积、阶段切换和内存表现；当前预缓存首装为 14 张姿态，不能把全部 50 张总量等同于首装下载量。
- [ ] RGBA 已完成；只有实测需要时补多尺寸 PNG／更小资产，并检查边缘、透明、动作一致性和 Reduce Motion。不得重新把历史 RGB 结论当成当前缺陷。
- [ ] 没有实物设备时明确保留待验收，手机视口模拟只作为布局证据。

**完成证据：** 真机矩阵逐项有结果，设备或网络相关未通过项有明确发布影响；不是只列浏览器截图。

## T11：发布候选与文档收口（W12，发布准备）

**依赖：** T01—T10 中核心功能与发布必需项已有对应证据；未完成的非阻塞优化单列。

- [x] 按本轮实际改动执行适当回归、静态分析和 Release Web 构建；性能续作后的最新 build ID 为 `1c0036e1c11f90a9`，前序 `7e0a4516b041c795` 作为历史验收基线保留。
- [x] 将费用档案、改善设计、实施计划、运行说明、本地验收与 ROADMAP 对齐；历史证据保留日期，未来任务不标已完成。
- [x] 整理部署目标、配置差异、数据影响、已知限制和回退方案；不以 git reset／删除工作区代替恢复设计。执行记录见 [Web 改善验收](../../web-improvement-acceptance-2026-09-09.md#已执行的四个生成／音频函数部署) 。
- [x] 若仍有真实语音、普通账户权限、核心保存或设备阻塞，不宣称可发布；只交付当前可审阅候选和未完成清单。
- [ ] 在产物与方案都可审阅后，请求公开部署的独立确认。此计划没有授权发布，也不要求在文档阶段提前索取确认。

**完成证据：** 构建与验收对应同一候选版本，用户能清楚审核改了什么、验证了什么以及上线动作的实际范围。

## T12：后台提醒单独立项（W13，P2，暂缓）

- [ ] 仅在主人明确需要关闭网页后的提醒时，重新检查 [既有 Web Push 方案](../../web-push-plan.md)。
- [ ] 确认订阅表、RLS、VAPID、发送器、时区调度、重复提醒防护和失效订阅处理的最小实现与权限边界。
- [ ] 单独提交 schema／配置及运行成本方案，再安排实现与真机投递验收。本轮不创建订阅、secret 或定时任务。

## 验证命令与环境约定

下列命令已在 2026-09-09 的本地候选验收中执行。Deno 使用工作区 `output/playwright/deno-2.9.3/deno.exe`，未安装全局依赖；完整结果见 [Web 改善验收](../../web-improvement-acceptance-2026-09-09.md) 。

### Flutter 与浏览器测试

工作目录：`SelahFlutter`。T01—T04 先执行受影响的既有测试，新增测试文件存在后再加入命令；收口时执行全套测试。

~~~powershell
flutter test --no-pub test/web_models_test.dart test/web_controller_test.dart test/web_reliability_controller_test.dart test/web_app_test.dart
flutter analyze --no-pub lib/web
node --test test/browser_bridge.test.mjs test/browser_unload_protection.test.mjs test/service_worker_poses.test.mjs test/plush_assets.test.mjs
~~~

### Supabase 合约与 dry-run

工作目录：仓库根目录。下列测试只应使用本地代码／替身，不向模型发出真实请求；新增 usage 测试在 T06 创建后另行加入。

~~~powershell
deno test --allow-env --allow-read supabase/tests/speech_transcribe_test.ts supabase/tests/sentences_generate_test.ts supabase/tests/capture_contract_test.ts supabase/tests/audio_generate_test.ts supabase/tests/audio_delivery_test.ts supabase/tests/deployment_contract_test.ts supabase/tests/remote_acceptance_contract_test.ts
deno run supabase/scripts/remote_acceptance.ts
~~~

T06 的数据库测试使用隔离测试数据库；不在未确认的线上环境应用 migration。真实验收的执行参数、账户和调用上限在 T09 的具体评审中给出，不能直接把 dry-run 改为生产执行。

### 发布候选构建

工作目录：仓库根目录。沿用已有脚本和已配置的公开运行参数，缺失参数时明确报告，不改写环境文件。

~~~powershell
powershell -NoProfile -File SelahFlutter/tool/web.ps1 -Action build
~~~

每个任务更新 ROADMAP 时记录实际执行的命令、结果与未验证部分；不要复制上一轮成功记录作为新版本证据。

## 计划自检

- W01—W13 已分别映射到 T01—T12，无供应商替换或原生端新增任务。
- P0 包含正式页面输入保护、完整长文本、转写可用性和普通用户闭环；统计与缓存优化不能遮蔽 P0 阻塞。
- 本地实现、付费样本、数据库／配置与公开发布的边界均已标明；T06、T09 远端真实调用、T10 真机和公开发布仍保持未勾选。
- 数据契约、旧备份兼容、重复调用、失败恢复、账户隔离和实际设备证据均有验收入口。
- 后续从 T09 普通账户真实样本及 T06 schema 审阅继续，依据真实验证更新状态，不重复实施已验证的本地任务和已部署函数。
