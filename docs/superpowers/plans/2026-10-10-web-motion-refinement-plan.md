# Web 动效修整 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 `executing-plans` 逐任务实施本计划。步骤使用复选框（`- [x]`）跟踪；每个任务先写失败测试、再改代码、再验证。

**Goal:** 修正动画总开关遗漏与按压、首次入场判断的错误行为，在保留 1.4.0「可感知」品牌动效风格的前提下，收敛学习中高频出现的回馈幅度。

**Architecture:** 不新增依赖、不改数据模型。动效参数 token（350ms／70ms／20px／0.98、按压 0.94／0.96／0.90）保持不变，只修正结构与门控：所有会改变位置、大小、旋转的动画统一经过 `MotionScope`；入场序位只计内容元素；首次入场判断在 `initState` 记录初始分页。

**Tech Stack:** Flutter／Dart 3.44.9、Flutter Web、既有 `flutter_test` 与 Node 浏览器桥接测试。

## Global Constraints

- 不改 `.env`、密钥、CI／CD、Cloudflare 配置、Supabase schema、数据库与云端数据；不新增 Flutter、Node 或全局依赖。
- 保留页面状态、草稿、播放位置、账户切换、语言切换与「動畫效果」开关语义；关闭开关后所有位置、大小、旋转动画直出，仅颜色与透明度变化可保留。
- 高频动作（切句、播放、切页、揭示答案）只用轻量回馈；不新增装饰性循环动画。
- 动效 token 不改：入场 350ms／70ms／20px／0.98，按压 0.94／0.96／0.90；改动只发生在结构、门控和下列明确列出的幅度。
- 生产发布使用唯一 `pubspec.yaml` 版本；push `main` 触发 Cloudflare Pages 生产部署，该步骤须按全局 `AGENTS.md` 先说明、再取得主人当步确认。

---

## 调研依据（2026-10-10）

对照 10/3 动效方案、10/4 动效稽核和 Flutter 3.44.9 SDK 源码，并在专案外的临时副本用 widget 探针复现。

| 现象 | 证据 | 任务 |
| --- | --- | --- |
| 关闭开关后通知横幅仍滑入 | 60ms 时 `dy=-0.111`、透明度 0.72 | T1 |
| 关闭开关后底部导览指示器仍在动画 | 100ms 时指示器值 `0.80／0.20`（NavigationBar 默认 500ms） | T1 |
| 关闭开关后骰子仍旋转缩放 | 120ms 时 Transform 非单位矩阵 | T1 |
| 研究资料「更多背景资料」展开区块不受开关控制 | `ExpansionTile` 使用默认 200ms | T1 |
| 停用按钮按下仍缩到 0.94 | 七个使用处中六个会被停用；探针 `scale=0.94` | T2 |
| 从按钮开始滑动页面，按钮保持缩小到手指放开 | 滑动 150px 后 `scale=0.94`、点击次数 0 | T2 |
| 首次分页记录失效 | `late int _lastTab` 首次读取时已是新分页；导航序列 1→0→1→0→3 中，第二次回今天、第三次进聆听仍播放 100ms 页面淡入 | T3 |
| 间距元件占入场序位 | 聆听页 7 个子项，主卡 420ms 才开始、约 760ms 完成；可见元素相隔 140ms | T4 |
| 筆記页卡片先于搜索框出现 | 120ms 时卡片完整可见，搜索框 250ms 仍透明、600ms 才完整 | T5 |
| 聆听三键桌面宽按钮缩 0.94 | 主按钮宽约 250px，收缩约 15px | T6 |
| 每次听完精灵跳 15px、答对跳 27px | `plush_companion.dart` 幅度常量 | T7 |
| 抽屉内容淡入＋上移，注释写 280ms／16px，实际 240ms／12px | `selah_sheet.dart` | T8 |
| 全局强制 `InkSparkle.splashFactory` | Flutter 3.44.9 仅在 Android 原生默认使用，Web 默认 InkRipple | T9 |

无需修改：弹窗、底部抽屉、桌面选单、捲动定位和启动按钮载入图示已接开关；精灵闲置休息与隐藏分页暂停正常；导览图标弹跳放大约 3px、揭示答案直出，保持现状。

## Files and responsibilities

- `SelahFlutter/lib/design/selah_pressable.dart`：新增 `enabled`；指标位移超过 `kTouchSlop` 时回弹。
- `SelahFlutter/lib/design/selah_stagger_entrance.dart`：间距元件不占序位；最多三波；`FadeTransition`＋`ScaleTransition` 替换逐帧 `Opacity`。
- `SelahFlutter/lib/design/selah_sheet.dart`：抽屉内容仅淡入，修正注释。
- `SelahFlutter/lib/web/ui/web_learning_app.dart`：通知横幅时长门控、`NavigationBar.animationDuration`、`_ContentState` 初始分页、筆記标题区、网页主题水波。
- `SelahFlutter/lib/web/ui/companion_dice_button.dart`：关闭开关时不播放旋转缩放。
- `SelahFlutter/lib/web/ui/research_profile_widgets.dart`：`ExpansionTile` 动画门控。
- `SelahFlutter/lib/web/ui/listen_focus_controls.dart`、`web_start_action.dart`、`speed_selector.dart`、`loop_listening_panel.dart`：按压 `enabled` 与聆听三键强度。
- `SelahFlutter/lib/web/ui/plush_companion.dart`：完成／答对跳动幅度。
- 测试：`selah_motion_widgets_test.dart`（按压、入场、聆听三键）、新增 `web_motion_switch_test.dart`（开关覆盖、网页水波）、`web_page_entrance_test.dart`（首次分页、筆記入场）、`selah_sheet_test.dart`（抽屉）、`plush_companion_test.dart`（幅度）。
- `pubspec.yaml`：补丁版本 `1.10.1+19`；`CLAUDE.md`、`ROADMAP.md`、本文件。

## Task 0: 规范与文档先行

- [x] 归档本方案；`CLAUDE.md` 加入三条动效原则与实施授权；`ROADMAP.md` 新增阶段。
- [x] 单独提交文档，再进入代码。

## Task 1: 动画总开关覆盖（P0）

**Files:** `web_learning_app.dart`、`companion_dice_button.dart`、`research_profile_widgets.dart`、新增 `web_motion_switch_test.dart`。

- [x] 先写失败测试：开关关闭时，通知横幅第一帧即为终态；`NavigationBar` 指示器切页后一帧到位；骰子点击后无旋转缩放但名字照常更换；展开区块一帧完成。开关开启时三类动画仍存在。
- [x] 通知横幅 `AnimatedSwitcher.duration` 改用 `MotionScope.durationOf`。
- [x] 手机 `NavigationBar` 在关闭时传 `animationDuration: Duration.zero`，开启时保持 SDK 默认。
- [x] 骰子在关闭时不启动控制器。
- [x] `ExpansionTile` 关闭时传 `AnimationStyle.noAnimation`。

## Task 2: 按压正确性（P0）

**Files:** `selah_pressable.dart` 与六个使用处。

- [x] 先写失败测试：`enabled: false` 时按下缩放恒为 1；按下后移动超过 `kTouchSlop` 立即回弹；轻微抖动（小于 `kTouchSlop`）不取消；点击行为不变；开关关闭时仍恒为 1。
- [x] `SelahPressable` 新增 `enabled`（默认 `true`）并追踪起始指针位置。
- [x] 六个使用处传入与 `onPressed != null` 一致的条件：启动按钮、语速选择、研究资料保存、播放主按钮、同步按钮、聆听三键。

## Task 3: 首次分页判断（P1）

**Files:** `web_learning_app.dart`（`_ContentState`）、`web_page_entrance_test.dart`。

- [x] 先写失败测试：导航序列 1→0→1→0→3→1→3→0 中，只有第一次进入聆听与筆記播放 100ms 页面淡入。
- [x] `_lastTab` 改为 `initState` 取值，并把初始分页加入已访问集合。

## Task 4: 入场结构（P1）

**Files:** `selah_stagger_entrance.dart`、`selah_motion_widgets_test.dart`。

- [x] 先写失败测试：七个子项（含三个间距）时，第四个内容项的起点不晚于 140ms、终点不晚于 490ms；任意子项数量入场总长不超过 490ms；开关关闭时第一帧即为终态；仍只在 `animate` 变为 `true` 时播放一次。
- [x] 无子节点的 `SizedBox` 不占序位；序位上限为 3 波（每波 70ms）；整体窗口 = 350ms + 最多 2×70ms。
- [x] 用 `FadeTransition`＋`ScaleTransition` 与不重建子树的位移替换逐帧 `Opacity`，350ms、70ms、20px、0.98 不变。

## Task 5: 筆記页入场顺序（P1）

**Files:** `web_learning_app.dart`（`_NotesPageState`）、`web_page_entrance_test.dart`。

- [x] 先写失败测试：首次进入筆記页 120ms 时，搜索框与第一张卡片同时可见。
- [x] 标题区改用普通 `Column`，移除 `entrance` 参数及调用处。

## Task 6: 聆听三键强度（P2）

**Files:** `listen_focus_controls.dart`、`selah_motion_widgets_test.dart` 或聆听 UI 测试。

- [x] 先写失败测试：「听下一句」按下缩放为 0.96。
- [x] 三个按钮统一用次级强度。

## Task 7: 精灵反馈幅度（P3）

**Files:** `plush_companion.dart`、`plush_companion_test.dart`。

- [x] 完成事件跳动由 15px 降为 8px，答对由 27px 降为 14px；姿态切换、角度和其他动作不变。
- [x] 已有测试覆盖「事件只播放一次、隐藏时不动」，补充幅度断言。

## Task 8: 抽屉内容（P3）

**Files:** `selah_sheet.dart`、`selah_sheet_test.dart`。

- [x] 抽屉内容只保留 240ms 淡入，移除 12px 上移，注释与实际一致；原生抽屉上滑保持。

## Task 9: 网页水波（P3）

**Files:** `web_learning_app.dart`（`_theme`）、`web_motion_switch_test.dart`。

- [x] 网页主题使用 `InkRipple.splashFactory`（Flutter 的 Web 默认）；原生 Flutter 主题 `SelahTheme` 不变。

## Task 10: 验证与发布

- [x] `flutter analyze --no-pub`、`flutter test --no-pub`（基线 446 项）、`tool/web.ps1 -Action build`。
- [x] Release 版浏览器检查：390×844 走通五个页面并关闭「動畫效果」；1280×800 只检查了引导与今天页。1180px 以上的陪伴栏默认隐藏，未单独打开检查。
- [x] 版本升至 `1.10.1+19`；更新 `ROADMAP.md`，只把已验证事项标为完成；真机检查如无法执行须明确写「待确认」。
- [x] 合入本机 `main`。
- [ ] push `main` 与 Cloudflare Pages 生产部署须按 `AGENTS.md` 取得主人当步确认。

## 实施与验证结果（2026-10-10）

- T1—T9 已按上述方案实现，每项先写测试再改代码：T1、T3、T5、T6、T7、T8、T9 的测试先以行为断言失败；T2 因 `enabled` 参数尚不存在先编译失败（旧行为已由探针复现）；T4 因入场尚未使用 `FadeTransition` 先失败。
- 修正方案中的一处推断：调研时写到「第一次返回今天页会重播入场」。逐项核对 `SelahLazyIndexedStack` 缓存的旧页面实例后，今天页入场并不会重播；已确认的症状只有 100ms 页面淡入，T3 的测试据此只断言页面淡入。
- T7 未录制两版对比，直接采用推荐幅度（8px／14px）；T9 采用 Flutter 的 Web 默认 `InkRipple`，浏览器录像未单独确认闪光纹理，两者均为常量级改动，可随时调回。
- 验证：`flutter analyze --no-pub` 无问题；`flutter test --no-pub` 467 项通过；Release 构建版本 `1.10.1+19`、本地 Build ID `837952bf8babb588`。浏览器（Chrome 无头）在 390×844 走通引导、今天、聆听、练习、筆記、设置与关闭「動畫效果」，1280×800 检查了引导与今天页，控制台 0 错误。浏览器录屏的帧率不稳定，动画时序以 widget 测试为准；手机真机与受控网络验收待确认。
