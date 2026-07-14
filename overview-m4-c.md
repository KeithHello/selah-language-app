# Selah M4-C 使用者体验与无障碍概览

## 已实现并通过 CI

M4-C 在现有 Swift Package 中完成了可验证的核心层，不伪造当前仓库不存在的 Xcode Widget Extension target。功能提交 `d1d3738` 与文档提交 `5b105d4` 均已通过 GitHub Actions Build & Test；本次清理移除了未使用的日历参数与死代码，并补充了权限拒绝回归测试。

本地通知新增 `LocalNotificationService`、可注入的 `LocalNotificationClient` 和 `LocalNotificationPreferences`。服务支持 `HH:mm` 解析、无效时间安全回退、每日通知排程，以及关闭通知时撤销排程。iOS `UserNotificationsClient` 只在可用平台条件编译；通知文案不携带用户句子。`UserPreference` 会在 App 层转换为 sendable 偏好值后再交给 actor，避免跨并发域传递 SwiftData model。

Widget-ready 新增 Codable 的 `WidgetReadySnapshot` 与 `WidgetReadySnapshotBuilder`。摘要包含今日句子数、已聆听数、待复习数、推荐动作、精灵名称和生成时间；计数会归一化，用户可见字符串有确定性长度上限，契约不保存原始个人句子。

无障碍支持新增 `selahAccessibility`、装饰内容隐藏和 Reduce Motion 策略辅助，并先应用到 `iOSRow`、`QuizCard` 与 `PetView` 的关键交互和视觉元素。`SelahContrast` 提供 WCAG 普通文字／大文字对比度验证；现有自定义字体保留，同时明确后续 iOS UI target 应使用 Dynamic Type 缩放方案。

## 测试

新增 `SelahTests/M4AccessibilityAndExperienceTests.swift`，覆盖通知时间解析与回退、注入式排程／撤销、Widget 摘要边界与隐私、Reduce Motion 行为和 WCAG 对比度阈值。

本机环境没有 Swift／Xcode 工具链，因此无法执行本地 `swift build` 或 `swift test`。权威验证由 GitHub Actions 在 `macos-15` 完成：`swift package resolve`、`swift build` 与 `swift test` 均通过，相关 run 为 `29298637595` 和 `29298780396`。

## 后续

在真实 Xcode iOS target 建立后，需要补做 UserNotifications 权限流程、WidgetKit Extension 接线、Dynamic Type 全屏审计、VoiceOver 真机巡检、Reduce Motion 动画验收和浅色／深色模式对比度截图检查。M4-D 继续处理隐私政策、权限解释、日志脱敏和发布准备。 
