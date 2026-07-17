# Selah 开发路线图

> 最后更新：2026-07-17
>
> 状态依据：仓库当前代码、GitHub Actions 和只读端到端接线审查。
>
> 完成口径：遵循 `CLAUDE.md` 的五级完成定义。

## 当前阶段

非动画系统的代码内实施已完成；首批 10 个原生 SwiftUI 精灵动画也已完成代码接线并通过 CI。长语音准备接口的部署清单、专用配额和幂等账本已补齐并通过 CI。第二阶段已完成远端 migration、7 个 Edge Functions 部署和 30 条 seed 导入；真实翻译验收因 `.env` 中 OpenAI key 返回 401 而暂停。真实 iOS 17+ App target、认证、AI／音频运行路径、学习数据闭环、Widget、原子生成额度及 SwiftData 版本迁移均已接线；真机视觉和发布材料仍属于外部环境验收。

## 已验证基线

| 项目 | 层级 | 证据 |
|---|---|---|
| Swift 核心模型、仓库、推荐、复习、可靠性模块 | 核心层已验证 | GitHub Actions run `29339236287`：227 tests，1 skipped，0 failures |
| Supabase schema 与 Edge Function 源码 | 本地数据库层已验证 | 4 个 migration、5 个 Edge Functions；临时 Supabase 的 pgTAP 与并发测试通过，当前未重新执行远端部署 smoke test |
| Seed 内容 | 内容已验证 | `v8.2`，30 句，6 类各 5 句，无重复 ID、无空核心字段 |
| 动画参考 | 样片存在 | 3 个 HyperFrames MP4；首批 10 个原生 SwiftUI 动画进入当前试点 |

## 进行中

### P0：真实产品闭环

- [x] 建立可编译的 iOS 17+ App target，生成基础 App 信息并纳入模拟器 Release 构建门禁。
- [x] 实现 Supabase Email／Password MVP 认证边界，会话保存于 Keychain，启动时安全恢复。
- [x] App 启动路径按运行配置建立真实 `SelahAPIClient`；未配置或未登录时明确阻止，不再静默回退 Mock。
- [x] Onboarding 幂等保存精灵名称、3 个种子句和默认偏好状态。
- [x] 修复语音权限、按住／释放录音、最终 transcript 保存与音频引擎停止，并通过核心测试与 iOS 编译。
- [x] Today 保存统一经过音频生成、下载、校验、缓存；Listen 读取真实本地文件。
- [x] 修复离线重试 payload，保留目标文本、声线、原因和失败是否可重试。
- [ ] 完成中文输入 → 英文生成 → TTS → Listen → Practice 的真实端到端验收。

### P1：产品数据闭环

- [x] 保存生成句子时建立词汇条目。
- [x] Notes 查询真实句子、掌握数、词汇和已解锁回忆。
- [x] 学习事件触发精灵回忆解锁。
- [x] Settings 可进入、可编辑并持久化声线、速度、提醒等偏好；iOS 上同步每日本地提醒。
- [x] Night Preview、本地通知和 Widget 与真实 iOS 生命周期接线。
- [x] 建立受系统调度的后台刷新；恢复离线生成队列并刷新 Widget，同时保留前台恢复兜底。
- [x] 建立版本化 SwiftData schema 与 V1→V2 磁盘升级 fixture；迁移失败时保留原数据并显示恢复界面。

### P1：后端与安全

- [x] 更新失效的 Deno 测试，使测试验证行为而非源码字符串。
- [x] 将 Supabase 格式、lint、类型检查与测试加入 CI。
- [x] 为生成接口增加每用户额度、原子速率限制与客户端请求幂等账本；临时数据库 8 路并发验证仅 1 个请求获得额度。
- [x] `events.metadata` 改为按事件类型区分的明确字段白名单。
- [x] JWT helper 明确命名为解析网关已验证 claims，并注明签名验证依赖 `verify_jwt = true`。
- [x] `sentences-prepare` 纳入 Edge Function 配置与完整部署脚本，使用独立 `capture_preparation` 配额和幂等 ledger；未配置或未部署远端前不会调用 OpenAI。
- [ ] 重新执行部署 smoke test，记录当前远端版本证据。

### P2：发布准备

- [x] iOS Simulator Release 构建与无签名 `.xcarchive` 归档；校验 App、Widget bundle 并保存 CI artifact。
- [ ] 真机验证 Speech、Microphone、AVAudioSession、离线恢复、低存储和通知权限。
- [ ] App Icon、隐私政策 URL、截图和 App Store Privacy Nutrition Label；App 与 Widget 的 `PrivacyInfo.xcprivacy` 已进入归档并验证。
- [ ] TestFlight 内测与 release build 验证。

## 2026-07-17 Native animation pilot

- [x] 完成首批 10 个 SwiftUI 原生动画及 Today／录音／Listen／Practice 触发接线。
- [x] 通过 Swift 核心测试和 iOS 模拟器 Release 构建／无签名归档；GitHub Actions run `29514198511`：259 tests，1 skipped，0 failures。
- [ ] 完成真实设备视觉、触控时序、性能和 Reduce Motion 验收。
- [ ] 连续自用后再决定是否扩展剩余 P0、P1、P2 动画；本阶段不引入 Lottie、Rive 或视频资产。

## 明确排除

- 剩余 110 个宠物动画及 Rive／Lottie 动画系统；首批 10 个试点不属于排除项。
- 未经主人确认的 Supabase 外部配置变更、密钥修改、部署、合并或公开发布；本轮仅在当前分支和 CI 临时数据库执行已获授权的 migration。

## 阻塞与外部条件

- 当前 Windows 环境没有 Swift 与 Xcode；Swift／iOS 验证依赖 macOS CI，Deno 检查可通过临时 CLI 执行。
- TestFlight 需要 Apple Developer 账号、签名与 App Store Connect 权限。
- 后端远端迁移、认证策略变更和线上部署属于外部状态变更，执行前需主人再次确认。

## 最近验证

- 2026-07-14：GitHub Actions `29339236287` 成功，HEAD `0eb8c56`。
- 2026-07-16：确认当前仓库仍无 Xcode project／iOS target；本机无 Swift、Deno、Xcode。
- 2026-07-16：GitHub Actions `29434797968` 成功，HEAD `eb2e569`；Swift 233 个测试（1 skipped、0 failures），Deno 124 个测试（0 failures），格式、lint 与 Edge Function type-check 全部通过。
- 2026-07-16：GitHub Actions `29435122636` 成功，HEAD `715a5db`；Notes 的真实句子统计、分类过滤、词汇和已解锁回忆接入通过 Swift 与 Deno 双端 CI。
- 2026-07-16：GitHub Actions `29435376954` 成功，HEAD `2826ff6`；设置持久化测试、Swift 构建测试与 Supabase Deno 全套检查通过。
- 2026-07-16：GitHub Actions `29435596159` 成功，HEAD `30529f7`；Onboarding 名称与三句 Seed 幂等持久化测试及双端 CI 通过。
- 2026-07-16：GitHub Actions `29436084806` 成功，HEAD `0d3bd7a`；首次真实 iOS Simulator Release 构建、Swift 核心测试与 Supabase Deno 门禁全部通过。
- 2026-07-16：GitHub Actions `29464700822` 成功，HEAD `9903999`；Night Preview 持久化与事件测试、iOS 构建及 Deno 门禁通过。
- 2026-07-16：GitHub Actions `29466371853` 成功，HEAD `f9fab51`；Keychain 会话、运行配置、真实服务接线及移除产品 Mock 回退通过三门禁。
- 2026-07-16：GitHub Actions `29466706748` 成功，HEAD `ea4de30`；真实 TTS 下载、校验、缓存与离线重试接线通过三门禁。
- 2026-07-16：GitHub Actions `29468653533` 成功，HEAD `aee3a9b`；Widget Extension、App Group 快照和生命周期刷新通过三门禁。
- 2026-07-16：GitHub Actions `29468811339` 成功，HEAD `27e3328`；生成中音频清单复用及防重复 TTS 调用通过三门禁。
- 2026-07-16：GitHub Actions `29469098753` 成功，HEAD `f8571dd`；iOS 后台刷新注册、调度、离线队列恢复及 Widget 刷新通过三门禁。
- 2026-07-16：GitHub Actions `29469244363` 成功，HEAD `41fa2af`；生成并校验包含 Widget Extension 的无签名模拟器 `.xcarchive`，归档 artifact 上传成功。
- 2026-07-16：GitHub Actions `29469491952` 成功，HEAD `1ed6795`；App／Widget 隐私清单进入归档并通过 plist 校验，归档上传动作升级至 Node.js 24 且无弃用告警。
- 2026-07-16：GitHub Actions `29479890128` 成功，HEAD `87bc44d`；4 个 Supabase migration、15 项 pgTAP 契约、8 路并发额度竞争、134 项 Deno 测试、Swift 与 iOS 归档全部通过。
- 2026-07-16：GitHub Actions `29480172533` 成功，HEAD `8e72955`；SwiftData V1→V2 真实磁盘升级保留数据，Swift 248 个测试（1 skipped、0 failures），Supabase、iOS 构建与归档全部通过。
- 2026-07-17：GitHub Actions `29514198511` 成功，HEAD `f464ed4`；首批 10 个原生 SwiftUI 精灵动画的状态机测试、Swift 259 个测试（1 skipped、0 failures）、iOS Simulator Release 构建／归档、Supabase Deno、临时数据库 migration／pgTAP／并发检查全部通过。
- 2026-07-17：GitHub Actions `29569616987` 成功，HEAD `ffce932`；远端验收运行器契约、Deno、Swift、iOS Simulator Release 归档、4 个 migration、18 项 pgTAP 和并发额度检查全部通过；未执行真实远端调用。
- 2026-07-18：远端项目 `ijonabyyppmgvoufgamt` migration `001`–`004` 已应用，7 个 Edge Functions 为 ACTIVE，30 条 seed sentences 导入成功；真实验收在翻译 provider 处返回 HTTP 502，直接 OpenAI `/v1/models` 检查确认 key 为 `invalid_api_key`，TTS 尚未调用。
## 2026-07-16 Long-voice hybrid learning flow

- [x] Local conservative disfluency cleanup, segment suggestions, editing, and merge.
- [x] CaptureDraft and LearningSegmentDraft SwiftData V3 migration.
- [x] AI preparation and 1–5 segment batch translation Edge Functions with strict JSON Schema and atomic quota handling.
- [x] Today UI/ViewModel confirmation, batch translation, review, save, and existing TTS/Listen/Practice retry pipeline reuse.
- [x] GitHub Actions run `29495850665`: Swift, iOS archive, Deno, Supabase migration, pgTAP, and concurrency checks passed.
- [x] GitHub Actions run `29567690871`: `sentences-prepare` 配额／幂等接线、7 个 Edge Function 部署清单、Swift、iOS archive、Deno 144 tests、pgTAP 18 tests 和并发检查全部通过；未执行远端部署。
- [ ] Real remote Supabase + OpenAI key acceptance: auth, quota, AI quality, TTS generation, and network retry.
- [ ] Product follow-up: Japanese target language, capture grouping queries, recording recovery, and 120 animation assets.

## 阶段二至阶段十

- [x] 阶段二（远端验收准备）：新增默认 dry-run 的 `remote_acceptance.ts`，覆盖认证、bootstrap、长语音整理、幂等重放、批量翻译、TTS、signed URL 和音频下载；执行模式必须显式设置 `REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true`。
- [x] 阶段二（远端部署）：远端 migration `001`–`004`、7 个 ACTIVE Edge Functions 和 30 条 seed sentences 已完成；未执行远端回滚、合并或发布。
- [ ] 阶段二（真实远端验收）：密钥轮换、真实 OpenAI 质量与配额、TTS／Listen／Practice、重试和成本证据；当前阻塞为 `.env` 中 OpenAI key 返回 HTTP 401 `invalid_api_key`。
- [ ] 阶段三（真实 iOS 运行验收）：macOS／iPhone 上验证麦克风、Speech、AVAudioSession、权限、断网恢复、Listen 播放结束和 Practice 时序。
- [ ] 阶段四（动画可视化与首轮自用）：开发者动画 Gallery、CI 可下载模拟器包／录屏，并用首批 10 个动画进行个人试用。
- [ ] 阶段五（稳定性修正）：根据真实试用修正长录音恢复、段落合并、音频缓存、重试和学习数据边界。
- [ ] 阶段六（动画扩展）：在首轮试用稳定后，按优先级扩展剩余 110 个动画；继续优先 SwiftUI 原生实现，必要时再评估 Lottie／Rive。
- [ ] 阶段七（日语支持）：扩展目标语言模型、提示词、TTS 声线、UI 文案、配置开关和验收用例。
- [ ] 阶段八（发布准备）：App Icon、隐私政策 URL、截图、Privacy Nutrition Label、权限说明和发布 checklist。
- [ ] 阶段九（TestFlight）：签名 release build、内部测试、崩溃／性能／耗电检查和小范围反馈修复。
- [ ] 阶段十（正式发布与运营）：主人确认后再进行 App Store 发布、远端生产配置、监控、配额告警和版本迭代。
