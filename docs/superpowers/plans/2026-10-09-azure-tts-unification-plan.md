# Azure 三语 TTS 与响度统一实施计划

## 范围

依照设计规格 `docs/superpowers/specs/2026-10-09-azure-tts-unification-design.md` 实现本地代码、测试和工具。本计划不包含真实 Azure 付费合成、云端配置／密钥、migration、云服务或 Supabase Edge 部署、CI/CD 修改、种子资产覆盖或公开发布。

## 顺序与验收

1. **语音契约与路由**：将中文／日语母语及美式／英式英语映射到 Azure voice；明确 SSML locale、rate、pitch、provider model、cache identity，删除新 TTS 的 OpenAI fallback。回归检查每个 profile、错误 locale 和 SSML 转义。
2. **计费和 admission**：增加 Azure SSML billable-character 计数与可验证的服务端单位价格参数；将计费单位与会员码点额度分离；缺价时 fail closed。测试 Han 双计数、非 Han、SSML profile markup、超大／缺失／非法费率，以及原会员额度不变。
3. **音频处理器**：实现标准库 Python HTTPS 服务、bearer 校验、大小／哈希／并发／超时保护、FFmpeg 两遍 loudnorm、输出格式和指标验收；提供容器定义与无 Azure 依赖的单元／本地合成信号测试。
4. **Edge Function 集成**：统一使用 Azure；校验 normalizer 配置和报价；保存确定性 source 中间对象；调用处理器并核对 revision、摘要、格式和实测响度；ready manifest 只指向校准成品；失败可从源音频恢复且不重复请求 Azure；成功清理中间源。覆盖 generation admission、usage 日志、幂等、并发冲突、失败恢复和缓存命中。
5. **Flutter 客户端**：所有受支持语言都返回 Azure route identity，客户端 cache 升到 `audio:v3` 并加入处理器 revision；确认英语、中文、日语和不同 profile 会生成不冲突且可增量补齐的 track keys。
6. **随包种子工具**：扩展生成工具以为实际 source/target 语种和 profile 构造 Azure SSML、生成音频并运行本地校准；更新清单 inventory 和 package integrity 规则。只跑 dry-run／现有文件只读校验，绝不生成真实音频或覆盖资源。
7. **本地验收与路线图**：执行修改相关的 Python、Node、Deno、Flutter tests、`flutter analyze --no-pub`、`flutter build web --release` 与 seed 工具 dry-run；只有实际通过的检查才记作完成。记录缺少云端计费单价／normalizer 配置、付费试听／种子重制与云端部署审批等后续门槛。

## 完成条件

- 本地代码没有新 TTS OpenAI 路由或 fallback；Azure 与缓存／Storage 元数据区分所有语言、profile 和 normalizer revision。
- 对外可交付的每个新 MP3 都能证明输出为统一格式且响度／真峰值达标；处理器不可用时不会返回 raw 成品。
- Azure 费用的未知值继续明确为未知；admission 没有经核实的单价时 fail closed，会员字数规则不变。
- 所有授权范围内检查通过，`ROADMAP.md` 有真实验证状态和未完成的外部配置门槛。
