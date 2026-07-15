# Selah 开发路线图

> 最后更新：2026-07-16
>
> 状态依据：仓库当前代码、GitHub Actions 和只读端到端接线审查。
>
> 完成口径：遵循 `CLAUDE.md` 的五级完成定义。

## 当前阶段

非动画系统完整化实施中。当前工程具有大量已测试核心模块，但仍是 macOS Swift Package；真实 iOS App target、认证、真实 AI／音频运行路径和多项产品数据闭环尚未完成。

## 已验证基线

| 项目 | 层级 | 证据 |
|---|---|---|
| Swift 核心模型、仓库、推荐、复习、可靠性模块 | 核心层已验证 | GitHub Actions run `29339236287`：227 tests，1 skipped，0 failures |
| Supabase schema 与 Edge Function 源码 | 代码存在 | 3 个 migration、5 个 Edge Functions；当前未重新执行部署 smoke test |
| Seed 内容 | 内容已验证 | `v8.2`，30 句，6 类各 5 句，无重复 ID、无空核心字段 |
| 动画参考 | 样片存在 | 3 个 HyperFrames MP4；正式动画系统不在本轮范围 |

## 进行中

### P0：真实产品闭环

- [ ] 建立可编译、可启动的 iOS 17+ App target 与资源打包。
- [ ] 确定并实现 MVP 认证边界；推荐 Supabase 匿名会话，后续可绑定账号。
- [ ] App 启动路径建立真实 `SelahAPIClient`，句子和音频服务不再固定使用 Mock。
- [ ] Seed 首次启动幂等导入；Onboarding 保存精灵名称、3 个种子句和默认设置。
- [ ] 修复语音权限、按住／释放录音、最终 transcript 保存与音频引擎停止。
- [ ] Today 保存统一经过音频生成、下载、校验、缓存；Listen 读取真实本地文件。
- [ ] 修复离线重试 payload，保留目标文本、声线和失败是否可重试。
- [ ] 完成中文输入 → 英文生成 → TTS → Listen → Practice 的真实端到端验收。

### P1：产品数据闭环

- [ ] 保存生成句子时建立词汇条目。
- [ ] Notes 查询真实句子、掌握数、词汇和回忆。
- [ ] 学习事件触发精灵回忆解锁。
- [ ] Settings 可进入、可编辑并持久化声线、速度、提醒等偏好。
- [ ] Night Preview、通知、后台任务和 Widget 与真实 iOS 生命周期接线。
- [ ] 建立版本化 SwiftData schema 与升级 fixture 测试。

### P1：后端与安全

- [x] 更新失效的 Deno 测试，使测试验证行为而非源码字符串。
- [x] 将 Supabase 格式、lint、类型检查与测试加入 CI。
- [ ] 为生成接口增加每用户额度、速率限制和并发去重。
- [x] `events.metadata` 改为按事件类型区分的明确字段白名单。
- [ ] 明确 JWT helper 仅解析 payload，认证依赖 `verify_jwt`；避免误导性安全边界。
- [ ] 重新执行部署 smoke test，记录当前远端版本证据。

### P2：发布准备

- [ ] iOS 模拟器构建与测试。
- [ ] 真机验证 Speech、Microphone、AVAudioSession、离线恢复、低存储和通知权限。
- [ ] App Icon、隐私政策 URL、截图和 Privacy Nutrition Label。
- [ ] TestFlight 内测与 release build 验证。

## 明确排除

- 120 个宠物动画及 Rive／Lottie 动画系统。
- 未经主人确认的 Supabase 外部配置变更、数据库迁移、密钥修改、推送远端或公开发布。

## 阻塞与外部条件

- 当前 Windows 环境没有 Swift、Deno、Xcode；完整 Swift／iOS 验证需 macOS CI 或 Mac。
- TestFlight 需要 Apple Developer 账号、签名与 App Store Connect 权限。
- 后端认证策略、数据库迁移和线上部署属于外部状态变更，执行前需主人确认。

## 最近验证

- 2026-07-14：GitHub Actions `29339236287` 成功，HEAD `0eb8c56`。
- 2026-07-16：确认当前仓库仍无 Xcode project／iOS target；本机无 Swift、Deno、Xcode。
- 2026-07-16：GitHub Actions `29434797968` 成功，HEAD `eb2e569`；Swift 233 个测试（1 skipped、0 failures），Deno 124 个测试（0 failures），格式、lint 与 Edge Function type-check 全部通过。
