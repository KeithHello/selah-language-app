# 最近表达直达与聆听模式统一开发计划

> **执行方式：** 按本计划逐项以测试先行完成实施；逐项校验后将真实结果写入 ROADMAP.md。

**目标：** 点击一条最近表达后直接在逐句听中定位到该句；逐句听和循环听共用一致的响应式卡片与主要操作位置，且循环状态来自真实播放会话。

**架构：** 学习控制器分别保存当前聆听页面模式和循环音频会话，提供账户内按 ID 定位入口及暂停式模式切换。提取有明确复用收益的聆听卡片和控制布局；循环控制继续调用现有音频桥，只向页面暴露实际会话句 ID、音频位置与时长。

**技术：** 现有 Flutter Web、Dart、Material、浏览器音频桥、Flutter 与 Node 内置测试；不增加依赖。

## 全局约束

- 只在正式 Flutter Web 的 lib/web/、web/ 及相关 test/、docs/ 和根级 CLAUDE.md、ROADMAP.md 内工作。
- 遵守项目的 900 logical px 断点、Selah 设计令牌、置顶句库顺序和三语文案规则。
- 循环仍独立于逐句听完、复习和成长记录；切换模式暂停音频且不自动播放。
- 不修改 SwiftUI、数据库、Supabase 服务、API、密钥、CI、依赖、配置或远端资源。
- 不提交或推送代码，不创建 PR，不部署 Cloudflare。

---

### Task 1：从最近表达按 ID 直达逐句听

**修改：** SelahFlutter/lib/web/learning_controller.dart、SelahFlutter/lib/web/ui/web_learning_app.dart。

**测试：** SelahFlutter/test/web_app_test.dart、SelahFlutter/test/listen_navigation_test.dart。

**行为和边界：**

- 最近表达点击后清除 Today 专用焦点状态，切换到普通逐句模式，以未归档账户句库按句子 ID 定位。
- 点击前从当前账户的有效句库重新查询；找不到时复用 listen_sentence_unavailable 错误。
- 同 ID 二次直达也触发滚动回卡片顶部并隐藏展开答案；不更改学习数据，不播放，不写事件。
- 「查看全部」进入原逐句页并打开句库；Today 推荐入口维持现有“已听后继续”流程。

**测试先行：**

1. 在 web_app_test.dart 中使用含两条句子、置顶顺序已变化的真实控制器，断言点击后 tab 为 1、activeSentence 为目标 ID、模式为逐句、答案入口可见、循环没有启动、today-focused-lesson 不存在。
2. 再次点击当前激活句时断言滚动回顶部、已展开答案收起。
3. 覆盖目标归档或切换账户后失效时的反馈与无跨账户回退。
4. 在 listen_navigation_test.dart 覆盖置顶后动态计算当前序号与相邻导航关系。

运行：在 SelahFlutter 执行 flutter test --no-pub test/web_app_test.dart test/listen_navigation_test.dart。确认功能断言按预期失败后，再实现入口。

### Task 2：将页面模式与播放会话分开并安全切换

**修改：** SelahFlutter/lib/web/learning_controller.dart、SelahFlutter/lib/web/ui/web_learning_app.dart、SelahFlutter/lib/web/ui/loop_listening_panel.dart。

**测试：** SelahFlutter/test/web_loop_controller_test.dart、SelahFlutter/test/web_loop_listening_ui_test.dart。

**行为和边界：**

- 由控制器集中保存逐句／循环页面选择；不再从 loopSessionVisible 推导 loopMode。
- 逐句听正在播放时切入循环先暂停普通音轨。切回逐句时对 starting、playing、gap、ready 循环会话暂停；保留 paused 状态和计时语义。
- 一次只允许一个模式切换。目标页显示不开始音频，也不取消有效循环会话。
- 最近表达显式要求进入逐句；聆听页外循环迷你播放器仍可控制和返回。

**测试先行：**

1. 在 web_loop_controller_test.dart 用 FakePlatform 记录 audioPause／audioLoopPause，验证切换方向和并发请求保护。
2. 在 web_loop_listening_ui_test.dart 断言只呈现一种页面、主操作唯一、迷你播放器只在离开聆听页后显示；ready 和 paused 会话都能切回逐句。
3. 用模拟时钟推进暂停后的墙钟，断言 remainingMs 冻结且恢复后继续原时长。

运行：flutter test --no-pub test/web_loop_controller_test.dart test/web_loop_listening_ui_test.dart。

### Task 3：提供循环会话准确的当前音轨快照

**修改：** SelahFlutter/web/selah_bridge.js、SelahFlutter/lib/web/learning_controller.dart。

**测试：** SelahFlutter/test/browser_loop_playback.test.mjs、SelahFlutter/test/web_loop_controller_test.dart。

**行为和边界：**

- 现有 audioLoopStatus 返回 session.items[sentenceIndex].sentenceId，以及实际 Audio.currentTime 和 Audio.duration。
- gap、ready、paused 和 error 不得伪造为正在播放的音轨进度。
- 控制器仅从有效会话返回的句子 ID 显示当前学习卡；会话结束或账户 generation 变化时不改指到其他句子。
- 进度只用于展示；沿用现有下一句、暂停、继续、截止和语序调用。

**测试先行：**

1. Node FakeAudio 增加可控 currentTime 与 duration，分别断言播放、暂停和间隔状态快照。
2. 用两句队列验证状态中的句子 ID 来自音轨队列，不能使用置顶后的逐句序号推断。
3. 覆盖暂停冻结、停止和超时结束时的状态。

运行：node --test test/browser_loop_playback.test.mjs。

### Task 4：统一学习卡、进度和三按钮布局

**修改：** SelahFlutter/lib/web/ui/web_learning_app.dart、SelahFlutter/lib/web/ui/loop_listening_panel.dart、SelahFlutter/lib/web/ui/listen_focus_controls.dart。只有现有界面文件无法共享该布局时才增加 SelahFlutter/lib/web/ui/listen_focus_layout.dart。

**测试：** SelahFlutter/test/web_listen_focus_ui_test.dart、SelahFlutter/test/web_loop_listening_ui_test.dart。

**行为和边界：**

- 单句／循环共享分类与母语卡、英文答案入口、置顶外观、状态行、音频进度和紧凑语速控件。
- 手机使用可滚动正文和固定底部操作条；桌面最大内容宽度 860，控件在卡片下部可见。
- 左按钮分别为逐句「上一句」和循环「循环设置」；中间按钮显示加载、准备、开始、播放、暂停、恢复的真实状态；右侧沿用逐句或循环下一句行为。
- 循环进度外观与单句一致，但不开放跳播。循环时长更改时注明下次会话生效，当前倒计时不变。
- 换句收起旧答案与词义；模式切换且句子 ID 不变时保留答案展开状态。

**测试先行：**

1. 两种模式通过共用组件呈现相同的正文、进度、语速和控件位置。
2. 视口宽度 320、390、759、899、900、1280 和 1440 均无布局异常，键目标和操作顺序完整。
3. preparing、ready、playing、gap、paused、ended 状态具有对应标签和行为；长英文滚动不移动手机操作条。

运行：flutter test --no-pub test/web_listen_focus_ui_test.dart test/web_loop_listening_ui_test.dart。

### Task 5：循环设置和三语可访问文案

**修改：** SelahFlutter/lib/web/ui/loop_listening_panel.dart、SelahFlutter/lib/web/l10n/selah_strings.dart、SelahFlutter/lib/web/l10n/selah_zh_hant.dart、SelahFlutter/lib/web/l10n/selah_zh_hans.dart、SelahFlutter/lib/web/l10n/selah_ja.dart。

**测试：** SelahFlutter/test/web_l10n_test.dart、SelahFlutter/test/web_loop_listening_ui_test.dart。

**行为和边界：**

- 手机用底部抽屉、桌面用对话框；两者显示句数、语序、15／30／60 分钟、自定义时长、暂停计时提示、结束循环和完成。
- 所有新增状态、错误反馈和可访问名称纳入繁体中文、简体中文和日文。
- 打开、关闭设置不发起准备或播放；结束循环继续调用现有 stopLoop。
- 播放时改语序沿用桥接逻辑，从下一句生效；改时长仅影响下一会话。

**测试先行：**

1. 本地化测试覆盖新增键和值完整性。
2. 循环面板测试覆盖移动底部抽屉、桌面对话框及播放中的设置打开和关闭。
3. 循环控制测试断言调整会话时长不重置现有剩余时间。

运行：flutter test --no-pub test/web_l10n_test.dart test/web_loop_listening_ui_test.dart。

### Task 6：文档、全量回归和本地验收

**修改：** 根目录 CLAUDE.md、ROADMAP.md；维护本设计和本开发计划的验证结果。

**设计资料：** docs/superpowers/specs/2026-10-01-listen-mode-consistency-mobile.png、docs/superpowers/specs/2026-10-01-listen-mode-consistency-desktop.png。

**验证命令，从 SelahFlutter 执行：**

1. flutter analyze --no-pub
2. flutter test --no-pub
3. node --test test/browser_loop_playback.test.mjs
4. tool/web.ps1 -Action build
5. 在可用浏览器查看本地 Release 包的桌面与手机状态，验收最近表达定位、两种模式切换、循环设置、音频互斥、长文本和浏览器错误。
6. 从仓库根目录执行 git diff --check，确认无关未跟踪文件 cf-pricing.html 保持原样。

在 ROADMAP.md 如实记录命令输出和仍待 iPhone Safari、Android Chrome、真实账户或远端服务完成的验收，不部署。
