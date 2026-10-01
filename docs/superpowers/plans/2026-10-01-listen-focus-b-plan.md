# Selah 逐句聆听方案 B Implementation Plan

> **实施授权：** 主人已于 2026-10-01 明确要求基于本方案开发。本轮按 T1→T7 执行；每项先建立行为验证，再做最小实现，复选框只反映实际完成状态。

> **范围补充：** 主人随后明确要求整理代码、commit／push 到 GitHub 并部署，且已给出一般部署授权。提交只包含本方案相关文件；Cloudflare 的具体项目、分支别名、配置影响与风险须在每个远端操作前单独说明并确认。当前目标按预览环境准备，不默认触及生产。

**Goal:** 在同一个 Flutter Web 逐句聆听页落实手机固定操作条、桌面专注学习卡、按需句库与一键听下一句。

**Architecture:** 保留现有 shell、Today 推荐、循环听与真实音频链路。controller 提供当前句库和受账户保护的选句／相邻句操作；普通聆听页组合现有答案与词义内容、独立播放按钮组和响应式句库弹层。只新增本页所需的小组件，不重组其他功能。

**Tech Stack:** 现有 Flutter／Dart、Material widgets、Focus／Shortcuts／Actions、LearningController、LearningPlatform、真实 Web 音频与缓存桥接、既有三语文案表。

**Design source:** [UI／UX 设计与 U01—U16 验收矩阵](../specs/2026-10-01-listen-focus-b-design.md) 。手机和桌面 PNG 由该设计文档引用。

## Global Constraints

- 主人已授权按本计划实施产品代码、测试和本地构建；按 T1→T7 推进，不把未验证事项标为完成。
- 同一响应式 Web 页，沿用 900 logical px 的全局导航断点；普通学习区最大宽度 860，桌面句库对话框最大宽度 560。
- 进入页、打开句库与句库选句不新播放；上一句／听下一句由主动操作切换并播放；单句 ended 后停在当前句，首末不绕回。
- 本期只更新普通逐句页。Today 推荐队列与既有继续／返回流程、循环听音轨／时长／语序／迷你播放器保持原语义。
- 当前账户未归档句库与 `orderedListenSentences` 是唯一排序来源；不新增独立播放队列快照或持久化字段。
- 只由真实音频结束沿用现有 `listen_completed`；点击、换句、打开答案、词义、置顶和语速变化不新增完成记录。
- 复用 `_playGeneration`、`_accountGeneration`、`stopPlayback()` 和现有 `play()`，保持真实错误与账户隔离，不引入 Mock 产品路径。
- 手机操作目标至少 48×48，常规高度 52～56；长文本与 200％ 字体下内容可滚动，按钮不被裁切或覆盖。
- 继续使用 `SelahColors`、现有字体与 Reduce Motion。默认 zh-Hant，覆盖 zh-Hans、ja。
- 五个既有语速预设与 0.5～2.0 自定义范围保持不变。其他页的语速外观保持不变。
- 不增依赖，不改 `.env`、密钥、CI、数据库、服务端、音频资产、预缓存、原生客户端或远端配置。部署由后续范围补充单独授权，执行前仍按 Cloudflare 逐步确认规则。

## 1．只读基线与尚未完成的工作

准备时工作区干净，HEAD 为 `6c26d3f`。现有产品包含置顶、词义拆解、五档／自定义语速、Today 快速学习和循环听。方案 B 本身尚未实施。

已核对的接线事实：

- `_Content` 用 `Expanded`／`IndexedStack` 提供有界页面，并独立渲染消息、邀请和循环迷你播放器。
- `_PageFrame` 自身是滚动容器；把按钮放进它的末尾不能满足手机固定操作条。
- 普通 `_ListenPage` 在窄屏先展示整列句库；`_ListenDetail` 直接包含 `_PlaybackControls`。
- `selectSentence(..., autoplay: false)` 仅打开详情，普通选句没有自动停止另一句的保证；本页新封装必须明确停止旧播放。
- `play()` 和 `togglePlayback()` 内部使用 `_run()`；`_run()` 遇到已有 `busy` 会直接返回。新封装不能在外层 `_run()` 内再次等待这两个方法，否则播放会被忙碌保护跳过。
- `_poll()` 只在音频 key／会话匹配并真实 ended 时写学习完成。此机制直接复用。

开发准备时未运行本方案的产品测试或构建。历史 341 项通过等记录继续按原日期保留，不能算作本方案的验证；实施阶段将实际运行基线和计划中的验收命令。

## 2．预计文件范围

| 文件 | 后续职责 |
| --- | --- |
| `SelahFlutter/lib/web/learning_controller.dart` | 有效句库、当前本机账户作用域、切换锁、静音选择与相邻句播放封装 |
| `SelahFlutter/lib/web/ui/listen_focus_controls.dart`，新增 | 本页三个操作的状态、禁用、布局与可访问名称 |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 仅调整普通 `_ListenPage` 与相关详情／句库／控件接线；保留 Today、循环听分支及 shell |
| `SelahFlutter/lib/web/ui/speed_selector.dart` | 新增紧凑入口；复用预设、自定义对话框和偏好更新 |
| `SelahFlutter/lib/web/l10n/selah_strings.dart` | 注册／回退新文案键，复用当前查找结构 |
| `SelahFlutter/lib/web/l10n/selah_zh_hant.dart`、`selah_zh_hans.dart`、`selah_ja.dart` | 对应三语文案 |
| `SelahFlutter/test/listen_navigation_test.dart`，新增 | 队列边界、切换、静音选择、真实结束及账户／异步保护 |
| `SelahFlutter/test/web_listen_focus_ui_test.dart`，新增 | 播放按钮组、手机／桌面布局、句库、语速和长文本 |
| `SelahFlutter/test/web_listen_keyboard_test.dart`，新增 | 焦点、键盘、模态及重复按键 |
| `SelahFlutter/test/web_app_test.dart`、`web_listen_peek_ui_test.dart`、`web_l10n_test.dart` | 调整句库弹层入口并保留既有回归；覆盖三语 |
| `docs/listen-focus-b-acceptance-2026-10-01.md`，验收时新增 | 记录真实验证日期、命令、视口、截图与平台限制 |
| `CLAUDE.md`、`ROADMAP.md` | 根据后续授权和实际验证更新状态 |

新增 Dart 文件只放在既有 `lib/web/ui/`，测试替身只放 `test/`。本期不新建产品目录或提取公共框架。开发时先重新核对符号，按上述模块定位，不依赖会漂移的行号。

## 3．接口与状态契约

### controller 的拟新增接口

| 接口 | 输入与结果 |
| --- | --- |
| `List<LearnSentence> get listenSentences` | 返回当前账户未归档句子，调用既有 `orderedListenSentences`，不修改原列表 |
| `String get listenAccountScope` | 只读返回现有 `_accountId`，供页面与弹层识别账户变化，不增加存储 |
| `bool get listenNavigationBusy` | `busy` 与本页切换锁的合并结果；普通按钮和句库行使用同一保护 |
| `Future<void> selectListenSentence(String sentenceId, {bool autoplay = false})` | 重新查找当前有效句子；同句静音选择保留状态；另一句静音选择先停止旧单句再切换；主动播放选择复用 `play` |
| `Future<void> moveListenSentence(String currentId, int offset)` | 只接受 -1／1；按最新 `listenSentences` 求相邻句，无相邻句不操作；有效时调用自动播放的选句封装 |

切换锁是仅在当前请求期间存在的内存状态，账户重置时释放。调用前校验 initialized、句子所属账户与有效性，捕获账户 generation；每个异步返回处确认仍属该 generation，失效时不选句、不播音、不更新新账户锁。

选择接口不外包一层 `_run` 再调用 `play`／`togglePlayback`。用独立切换锁覆盖「停止旧音频、选句、开始新播放」整个窗口，现有播放方法负责其内部 busy 和错误。错误沿用真实消息；非法偏移不操作，过期句子 ID 通过现有消息通道设置 `listen_sentence_unavailable`，UI 使用设计文案 `listen.unavailable`，其他错误处理不变。

### UI 的拟新增接口

`ListenFocusControls` 接收 `uiLocale`、绑定当前句的 `playbackState`、`busy`、`Future<void> Function() onPlayback`，以及可空的 `Future<void> Function()? onPrevious`／`onNext`。空 callback 表示边界禁用，不代表隐藏按钮。

页面负责确认播放与当前句匹配，再传入状态；组件只呈现和等待 callback，不拥有音频、队列、账户或学习完成状态。loading 只在当前选择确为准备目标时显示，其他音频状态使用 `isPlaybackFor(sentence)` 校验。

中间动作规则：当前句 playing／paused 调用既有 `togglePlayback()`；idle／ended／error 调用 `play(sentence)`。三按钮只构建一份，手机放在滚动区外，桌面放在卡片底部控件区。

`SpeedSelector` 拟增加命名参数 `compact = false`。仅普通 B 页传 true，其他现有调用点保持原样；预设、范围、持久化和 `showCustomSpeedDialog` 共用。

测试定位键固定为 `listen-focus-card`、`listen-library-button`、`listen-sentence-picker`、`listen-previous`、`listen-playback`、`listen-next`、`listen-speed-compact`。句库沿用已有 `listen-sentence-picker`，避免更换无关测试语义。

## 4．任务与验证顺序

### T1：有效句库与受保护的前后切换（完成）

**Files:** 修改 `SelahFlutter/lib/web/learning_controller.dart`；新增 `SelahFlutter/test/listen_navigation_test.dart`。

**Interfaces:** 产出第 3 节全部 controller 接口；复用 `orderedListenSentences`、`play`、`stopPlayback`、`_current` 和现有账户重置流程。

- [x] 建立只在测试内使用的 LearningPlatform 替身：记录 action／payload，支持手动完成音频播放 Future、设置 `audioStatus` 和拒绝 `audioPlay`；缓存命中按真实布尔协议模拟。
- [x] 先写行为测试：A／B／C 中从 B 向前、再向后播放；首末与 0／1 条不越界；无效 offset 与过期 ID 不播音；置顶后按最新顺序导航。
- [x] 补静音选句、同句保留进度、提前换句不写完成、匹配 ended 仅记录一次、重复请求只接受一次、账户切换后晚到音频不回写的测试。
- [x] 运行 `flutter test --no-pub test/listen_navigation_test.dart`，确认新增行为先因 controller 接口缺失而失败；修正测试 ID 为有效 UUID 后专项通过。
- [x] 实现接口与短期切换锁，复用播放链路；账户切换会释放旧锁，异步完成受 generation 保护；未改持久化 schema、事件结构或全局导航。
- [x] 再运行导航专项、`listen_pin_test.dart`、`web_reliability_controller_test.dart`、`web_loop_controller_test.dart`，共 48 项通过。

**Acceptance:** U01—U05、U11—U12。此任务结束时 controller 行为可测，界面仍不宣称已完成。

### T2：三按钮播放操作组件

**Files:** 新增 `SelahFlutter/lib/web/ui/listen_focus_controls.dart`；新增 `SelahFlutter/test/web_listen_focus_ui_test.dart`；对应四份文案表同步设计第 8 节的全部新键，供 T3—T5 使用。

**Interfaces:** 消费 T1 的 callback 与 busy 保护，产出第 3 节 `ListenFocusControls`；读取设计第 5 节状态表与第 8 节三语文案。

- [x] 先写状态测试：idle 为播放、loading 禁用、playing 暂停、paused 继续、ended 重听；另一句的播放不改变当前按钮；边界按钮 disabled，点击只调用对应 callback 一次。
- [x] 写 320 宽、日语、200％ 字体测试，检查按钮目标、文字完整可读与 Flutter 无布局异常。
- [x] 运行 `flutter test --no-pub test/web_listen_focus_ui_test.dart`，确认组件缺失时的有效失败。
- [x] 实现一个无音频副作用的组件：按钮顺序固定，下一句主强调色，callback 内等待异步操作，按真实状态提供名称／禁用语义。
- [x] 完成设计第 8 节全部三语键并复跑上述专项。中间按钮不与下一句合并，不另增第四个播放按钮；T4 再做参数与完整性回归。

**Acceptance:** U02、U04、U10、U12、U15。

### T3：普通逐句页、手机固定操作条与句库弹层

**Files:** 修改 `SelahFlutter/lib/web/ui/web_learning_app.dart` 的普通 `_ListenPage`、句库、详情与控件接线；扩展 `SelahFlutter/test/web_listen_focus_ui_test.dart`。

**Interfaces:** 消费 T1 的当前句库／账户作用域和 T2 的操作组件；继续复用 `_ListenDetail` 的英文、词义与拆解展示。Today 与循环听分支保留原行为。

- [x] 先写默认隐藏句库与不出声、手机底部固定、桌面单卡、句库弹层选句／关闭、图钉不选句、账户改变清空弹层的测试。
- [x] 对手机操作条记录展开答案前、展开长答案并滚动后的矩形，要求操作条位置一致且正文可滚到最后；同时保留底部五项导航可用。对桌面验证长内容与底部控件分区。
- [x] 运行 `flutter test --no-pub test/web_listen_focus_ui_test.dart`，先确认当前常驻句库／滚动按钮行为与新设计不一致。
- [x] 让普通页在已有有界页面内分开滚动内容和操作区。控制组从普通详情内移到目标位置，卡片保留真实进度／缓存／词义，不出现两套按钮；卡片图钉绑定现有 `togglePinnedSentence`，显示真实置顶状态；使用一个组件适配两端，不改变 shell 断点。
- [x] 句库窄屏用 `showModalBottomSheet`，桌面用有界 `showDialog`，内部同一 `ListView.builder`。选句重新校验 ID，另一句静音停止旧音频，当前句仅关闭；加载中只浏览，图钉事件不冒泡到行。
- [x] 学习区域按账户作用域与句 ID 重置答案／词义；同句重听保留展开。切换新句后把内容滚动回句首，固定操作区位置不变。关闭弹层后恢复入口焦点。
- [x] 现有 `_MessageBar` 仅对新客户端错误码 `listen_sentence_unavailable` 使用 `listen.unavailable` 本地化，其他错误分支保持原样；在三语下验证过期行选择保留静音、提示可读。
- [x] 复跑 UI 专项，覆盖 320×640、390×844、430×932、844×390、900×700、1024×768、1440×900，以及有全局消息／邀请／陪伴栏时的可用高度。

**Acceptance:** U01、U05—U10、U15。循环听可见时普通操作条隐藏，与现有迷你播放器不堆叠。

### T4：紧凑语速与完整三语文案

**Files:** 修改 `SelahFlutter/lib/web/ui/speed_selector.dart` 与第 2 节四份文案文件；扩展 `SelahFlutter/test/web_listen_focus_ui_test.dart`、`web_l10n_test.dart`。

**Interfaces:** 产出 `SpeedSelector(compact: true)`，继续调用现有 `updatePreferences(speed: ...)`、`speedLabel` 与 `showCustomSpeedDialog`。

- [x] 先写当前值、五个预设、自定义 0.5／2.0 边界与非预设值的显示／保存测试，检查只有普通 B 页采用紧凑入口。
- [x] 为设计第 8 节新键验证三语存在、位置参数替换、没有裸 key／默认中文回退；原有播放／暂停／关闭／自定义与错误文案复用。
- [x] 运行 `flutter test --no-pub test/web_listen_focus_ui_test.dart test/web_l10n_test.dart`，确认新入口缺失时失败。
- [x] 实现紧凑选择层；自定义前关闭选择层，避免两个模态同时可操作。保持 preset chips 与自定义档的原有紫色语义，其他页面仍走默认呈现。
- [x] 复跑上述专项及 `flutter test --no-pub test/web_app_test.dart`，确保设置页原五档／自定义测试保持通过。

**Acceptance:** U13、U15。

### T5：焦点、键盘及弹层关闭

**Files:** 修改普通 `_ListenPage` 的 Focus／Shortcuts 接线；新增 `SelahFlutter/test/web_listen_keyboard_test.dart`。

**Interfaces:** 左右／空格调用与 T2 按钮相同 callback；消费页面当前 tab、句库／语速弹层状态与 T1 busy，不建立第二套导航逻辑。

- [x] 先写右键下一句、左键上一句、空格播放／暂停／恢复／重听的测试，检查每次键事件只调用一次音频动作。
- [x] 写焦点在按钮、进度滑块、语速自定义控件、句库弹层、其他 tab 时不会误换句的测试；Escape 关闭并恢复焦点，长按的重复事件忽略。
- [x] 运行 `flutter test --no-pub test/web_listen_keyboard_test.dart`，确认快捷键行为尚不存在。
- [x] 用 Focus／Shortcuts／Actions 按当前区域接线，输入和控件默认按键优先。按钮自身 Space 激活与区域快捷键不能重复触发；模态开启时屏蔽底层操作。
- [ ] 复跑键盘专项，并人工检查 Tab／Shift＋Tab 顺序、焦点可见、读屏名称和禁用边界。

**Acceptance:** U09、U11、U14—U15。

### T6：既有学习流程与真实音频回归

**Files:** 修改 `SelahFlutter/test/web_app_test.dart`、`web_listen_peek_ui_test.dart` 中受新句库入口影响的操作步骤；补 T1／T3 新专项用例。仅在发现本期引入的问题时修改相关产品接线。

**Interfaces:** 消费 T1—T5 的完成状态；沿用现有 LearningPlatform action／payload 与学习事件，不引入新的后台协议。

- [x] 更新已有「listen pin moves a sentence first and shows the purple state」测试：先打开句库，检查置顶排序与选中，再关闭并检查卡片提示；不删除原断言。
- [x] 保留词义测试中的同句切换、一次只展开一条、关闭与不写完成断言；仅把选另一句的入口改为句库弹层。
- [x] 回归 Today 的「先打开所选学习卡」「游客种子听完可继续」及 `today_suggestions_test.dart`，确认普通句库导航没有改变推荐顺序与听完判定。
- [x] 回归循环听准备／开始、暂停／恢复、下一句、迷你播放器、计时与完成隔离；准备／播放音频错误用既有真实错误形状断言。
- [x] 运行聆听专项与相关既有流程回归；最终在当前干净分支运行完整 `flutter test --no-pub`，379 项全部通过，无失败。

**Acceptance:** U03、U11—U13、U16。发现失败先核对输入、状态与已有工作实现，不通过删测试或屏蔽断言解决。

### T7：本地构建、浏览器验收与状态更新

**Files:** 本地构建由既有工具生成；新增 `docs/listen-focus-b-acceptance-2026-10-01.md`，更新 `ROADMAP.md`、`CLAUDE.md` 的实际状态。图片仅作为比对参考，不复制到应用资源。

**Interfaces:** 消费 U01—U16 和 T1—T6；产出有真实日期与平台区分的验收记录。

- [x] 当前干净分支 `flutter analyze --no-pub` 无问题、`flutter test --no-pub` 379 项通过、`git diff --check` 通过；从提交 `1ceccc3` 的干净快照运行 `tool/web.ps1 -Action build` 成功，Build ID `aad1d4ede820b49c`。因未提供 Supabase 公共配置，该包仅供本地验证。
- [x] 使用本地 Web 页面完成 1280×720 桌面冒烟：确认单句聚焦、句库入口和固定的上一句／播放／聆下一句控件；点击下一句后进入第 2／3 句并自动播放音频至结束。当前工作区另有 Build ID `71a94e0c469f3320` 的配置完整候选包，含 189 项预缓存和 Supabase 公共配置。
- [ ] 完成 U01—U16 全项真实浏览器验收；记录桌面／窄屏视口、语言、文字比例、Reduce Motion 和可保存的截图，不以生图代替实际渲染。
- [ ] 桌面与浏览器窄屏完整测试首次播放、播放后下一句、暂停换句、句库静音选择、首末边界、语速、真实离线缓存与拒绝播放重试。当前只完成桌面下一句及自动播放冒烟；无缓存的个人句须显示真实错误，不触发付费生成验收。
- [ ] iPhone Safari 和 Android Chrome 可用时，真实体验单手连续听五句、展开答案后继续、地址栏变化、横屏、抽屉关闭与安全区。设备不可用时单独记为未验证，保留可继续开发的本地结果。
- [ ] 将 U01—U16 的实际结果写入验收记录；检查每个改动可追溯到本设计，记录尚未完成的平台验收，并按已达到的层级更新路线图，待开发项不能提前勾选。

**Acceptance:** 已在本地验证的事项才标记完成。真机、线上与原生平台的结果分别报告；公开发布继续独立确认。

## 5．准备阶段与交付检查

| 阶段 | 当前状态 | 进入下一阶段的依据 |
| --- | --- | --- |
| 方案选择与概念图 | 主人已认可 B 及手机／桌面图 | 本次明确要求整理方案 |
| UI／UX 规范、计划与图稿归档 | 已完成 | 文件与链接检查通过；概念图已归档 |
| T1—T7 产品开发 | 已完成 | 代码提交 `1ceccc3`；实现与自动化回归已提交并推送 |
| 本地产品验收 | 部分完成 | 自动化、Release 构建及桌面冒烟通过；U01—U16 全量人工清单仍待完成 |
| 手机真机验收 | 尚未执行 | iPhone Safari／Android Chrome 真实设备可用后记录单手操作与音频结果 |
| Cloudflare 预览部署 | 已部署 | 现有记录指向 `codex-web-ux-reliability` 别名；部署源 `6c5bc8d` 包含实现提交 `1ceccc3`。生产未部署；本任务未独立打开线上页面验收 |

实施任务按 T1→T2→T3→T4→T5→T6→T7 执行。每个任务通过相应验证后检查 diff；提交只包含本期相关文件，用具体中文 commit 描述，不改历史。

实施与自动化验收已完成；浏览器窄屏完整流程、U01—U16 人工清单及真机结果仍待实际验证，不能以桌面冒烟或自动化测试代替。
