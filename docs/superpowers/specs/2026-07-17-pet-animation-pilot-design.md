# Pet Animation Pilot Design

## Goal

在不引入新动画依赖、不使用 OpenAI API、不影响学习闭环的前提下，把现有静态 SwiftUI 精灵升级为可被真实业务状态驱动的首批 10 个原生动画，形成可在个人设备上使用的初版。

## Scope

本轮实现：`IDLE-01 gentle-float`、`IDLE-09 blink`、`IDLE-25 leaf-sway`、`ACT-01 listen-enter`、`ACT-02 listen-playing`、`ACT-04 listen-complete`、`ACT-35 rec-recording`、`ACT-36 rec-done`、`ACT-29 quiz-good`、`ACT-31 quiz-fail`。

本轮不实现：剩余 110 个动作、粒子和复杂光效、Lottie、Rive、MP4 运行时素材、远端动画配置和 OpenAI 生成调用。

## Architecture

`PetAnimation` 保存稳定 ID、持续／一次性类型、优先级和参数；`PetAnimationController` 负责页面持续状态、一次性事件、中断和恢复；`PetSpriteView` 只负责用现有 SwiftUI Shape 渲染身体、眼睛、嘴巴、腮红和叶子；`PetView` 继续负责名字、心情和故事容器。

持续状态由 Today、录音、Listen 和 Practice 的真实状态转换而来。一次性反馈覆盖持续状态，完成后恢复当前状态；过时的一次性事件不排队。后台、视图消失和 Reduce Motion 会停止或降低动画幅度，绝不影响录音、播放、保存和评分。

## Integration

- Today 默认使用待机状态，叶子动作只在装饰已出现时启用。
- 录音进入 recording 时触发 `rec-recording`，录音完成并取得最终文本时触发 `rec-done`。
- Listen 进入页面触发 `listen-enter`，音频播放状态切换触发 `listen-playing`，第三遍盲听完成触发 `listen-complete`。
- Practice 的 clear 评分触发 `quiz-good`，failed 评分触发 `quiz-fail`；almost 在试点阶段回到中性待机。

## Verification

先为动画解析、优先级、覆盖恢复、Reduce Motion 和装饰门控写失败测试，再实现最小代码。随后运行完整 Swift 测试和 iOS 构建；Windows 本机不推断真机效果，真机验收需要 macOS／iPhone。

## Security and external boundaries

本试点不读取、保存或调用聊天中暴露的 OpenAI key。真实远端 Supabase／OpenAI 验收必须在 key 轮换后，由主人将新 key 设置为服务端 secret，并单独确认远端部署。
