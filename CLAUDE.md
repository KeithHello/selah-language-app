# Selah 项目规范

## 目标

Selah 是 iOS 17+ 原生语言学习应用。核心闭环是：用户用中文表达真实想法，系统生成自然英文与音频，用户完成聆听、理解、复习和开口练习。

## 当前工程边界

- `Package.swift` 当前只验证 macOS Swift Package 核心层，不等同于可运行的 iOS App。
- `Selah/` 包含 SwiftUI、SwiftData、服务与学习引擎代码。
- `supabase/` 包含数据库迁移、Edge Functions 和 Deno 测试。
- 动画系统首轮只实施 10 个 SwiftUI 原生试点动作；不得为了动画改动阻塞核心产品闭环。Lottie、Rive、120 个完整动作和远端动画素材不属于本轮范围。

## 完成定义

任何事项只能按以下层级报告，不得混用：

1. **代码存在**：实现文件已提交。
2. **核心层已验证**：单元测试通过。
3. **产品已接线**：真实 App 运行路径使用该实现，不再依赖 Mock 或静态占位。
4. **平台已验证**：iOS 模拟器／真机或 Supabase 部署环境验证通过。
5. **发布完成**：TestFlight／App Store 流程实际完成。

只有达到对应层级，`ROADMAP.md` 才能标记相应状态。

## 实施顺序

1. 先更新规范和 `ROADMAP.md`。
2. 测试先行：先复现失败，再写最小修复。
3. 优先打通一条真实端到端闭环，再补外围能力。
4. 每阶段完成后运行相关测试；提交前运行完整 Swift、Supabase 和 iOS 构建验证。
5. 实现并验证后同步更新 `ROADMAP.md`。

## 工程约束

- 匹配现有 Swift／TypeScript 风格，不做无关重构。
- OpenAI、Supabase 密钥只存在于环境变量或服务端 secret，不进入 iOS、源码、日志或 commit。
- iOS 客户端不能直接持有 OpenAI API Key。
- 产品运行路径不得静默退回 Mock；Mock 仅用于测试和 Preview。
- Seed 导入必须幂等；后台任务必须可中断、可恢复。
- 事件 metadata 使用白名单，禁止上传原始句子等自由文本。
- 新增数据库迁移、依赖、CI 配置、`.env` 或外部部署前必须取得主人确认。

## 验证命令

```bash
swift package resolve
swift build
swift test
deno test --allow-env --allow-read supabase/tests
```

iOS 工程建立后还必须执行项目定义的 `xcodebuild` 模拟器构建与测试命令。Windows 本机没有 Swift／Deno／Xcode 时，必须使用 macOS CI 或明确说明未验证，不能推断成功。

## 文档职责

- `README.md`：项目介绍、真实工程状态和运行方式。
- `ROADMAP.md`：当前阶段、已完成、进行中、阻塞、最近验证。
- `docs/`：设计决策、隐私边界和发布验收证据。
