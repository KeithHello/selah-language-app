# Selah M4-D 隐私与发布准备概览

## 已完成

M4-D 在现有 Swift Package 与 Supabase Edge Functions 中完成了可验证的隐私脱敏与发布准备文档，不伪造当前仓库不存在的 Xcode iOS target 或 App Store Connect 提交。

### 隐私与发布边界文档

新增 `docs/m4-d-privacy-and-release-readiness.md`，涵盖：隐私承诺、资料分类与用途、权限说明、日志脱敏规则、SwiftData migration policy、Provider fallback policy、BGTaskScheduler 边界、Apple Privacy Nutrition Label 草案与 M5 开始条件。

新增 `docs/m5-readiness-checklist.md`，明确 M5 启动前必须完成的工程基线、Xcode target、CI 验证、真机验收与 App Store Connect 前置条件。

### App 层敏感错误脱敏

`SelahAPIClient.errorDescription` 不再把 provider payload、token refresh reason、底层网络错误描述或 decoding 错误细节放入用户可见文案；只保留状态码与通用繁体中文安全文案。`safeUserMessage` 已在 M4-A 阶段完成，本次确认其覆盖所有错误分支。

`SelahApp` 初始化错误不再 `print` 底层 error 描述，改为 Toast 通用文案。`TodaySentenceViewModel` 与 `ListenViewModel` 的用户错误文案不再拼接 `error.localizedDescription`，改为固定安全文案。`AudioPlaybackServiceImpl` 的 failed state 同样不再暴露底层错误描述。

### Edge Functions 日志脱敏

四个 Edge Function（`sentences-generate`、`audio-generate`、`events`、`config-bootstrap`）的 `console.error` 不再输出 provider response body、生成内容、Supabase 错误 message 或原始 error 对象；只记录状态码与操作级错误标签。

### 回归测试

`SelahAPIClientTests` 已更新：验证 `serverError` 的 `errorDescription` 包含状态码但不包含 raw provider payload；验证 `tokenRefreshFailed` 的 `errorDescription` 不包含 refresh token reason。

### ROADMAP

ROADMAP.md 的 M4-D 隐私政策状态从 `❌` 更新为 `🟡 核心文件与日志脱敏完成`，注明需 CI、Edge Function 部署审查、真实 Xcode 权限与 App Store Connect 隐私问卷验收。

## 验证

本机环境没有 Swift／Xcode 工具链，无法执行本地 `swift build` 或 `swift test`。权威验证需由 GitHub Actions 在 `macos-15` 完成。本次修改尚未 commit 或 push，因此 CI 验证仍待执行。

## 后续

M4-D 的剩余验收项明确需要外部条件：真实 Xcode iOS target 的权限流程、Edge Function 部署后的平台日志审查、App Store Connect 隐私问卷、SwiftData migration 装置测试、BGTaskScheduler 真机验收与 WidgetKit Extension 接线。这些项不在当前 Swift Package CI 的可验证边界内。
