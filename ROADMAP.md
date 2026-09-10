# Selah 开发路线图

> 最后更新：2026-09-11
>
> 状态依据：仓库当前代码、本地自动化与浏览器验收，以及明确标记日期的历史 GitHub Actions 结果。
>
> 完成口径：遵循 `CLAUDE.md` 的五级完成定义。

## 当前阶段

### 2026-09-11 剩余 47 个 GIF 动作设计（设计完成，待审阅）

- [x] 主人已认可 `8777` 的 Stage 1 A01—A03 表现形式；已核对正式 50 张运行 PNG 和动作编号，本轮设计范围为其余 47 项。
- [x] 完成每项动作的短剧情、同阶段来源姿态、16 帧节奏与运动参数、衔接风险及后续制作验收要求；Stage 1 为 7 项，Stage 2—5 各 10 项，共 47 项、752 条逐帧记录。
- [x] 整理 `docs/superpowers/specs/2026-09-11-mascot-47-action-design.md` 及同名 JSON、`docs/superpowers/plans/2026-09-11-mascot-47-gif-production-plan.md`，独立总览位于 `output/mascot-gif-47-design-20260911/preview.html`，本地入口为 `http://127.0.0.1:8778/preview.html`。
- 最近验证：47 项编号完整唯一，所有帧引用同阶段来源、主姿态至少 11 帧、首尾来源及变换完全一致；50 张原始 PNG 与预览副本、三个已认可 GIF 与参考副本的 SHA-256 一致。设计 JSON 和计划副本一致，47 项文字说明及 HTML 下载链接有效，预览脚本语法检查通过。本轮新 GIF 为 0，应用资源未替换。
- 浏览器验证：总览已加载并检查桌面布局；Stage 5 显示 10 项，编号搜索定位 S5-A09，棋盘格切换与背景选中状态正常，展开表格含完整 16 帧。后续跨阶段组合筛选、窄屏及最终标签页展示检查被自动审批的工具额度限制中断，未列为通过。
- [ ] 主人审阅设计后，再进入配对预检、代表动作试制和剩余批次制作；原图静态分镜仍含源文件已有脚底影，透明无影子的成品验收属于后续 GIF 制作。

### 2026-09-10 Stage 1 默剧颜色与体态一致性修订（已生成，待审阅）

- [x] 已检查旧版参考帧与生成关键帧，确认完整角色重绘造成毛色、脸型及叶片变化；旧清理脚本按含手脚的总外接框归一化，无法保证躯干等大。
- [x] 通过内置 imagegen 生成统一身体及手脚母版，固定比例合成 A01「偷偷打招呼」、A02「憋笑露馅」、A03「挥手差点失衡」三个独立 GIF；身体不逐帧重绘或伸缩，三文件共用调色板。
- [x] 输出至 `output/mascot-gif-stage1-pantomime-20260910-v2/`，包含三个 GIF、48 张透明 PNG、三张 4×4 图集、固定图层、提示词、清单和验收记录；独立预览为 `http://127.0.0.1:8776/preview.html?fresh=consistent2`，提供逐帧控制和旧版对照。
- 最近验证：三个 GIF 均为 768×768、16 帧、无限循环、disposal=2，时长 2400／2600／2800 ms；PNG 最小留白 155 px，首尾一致。解码调色板完全相同，同一腹部区域经姿态补偿后的 RGB 均值帧间变化最大为 1.1104／255；图集每格与 PNG 母版完全一致。联系图、浏览器深色背景、暂停第 11 帧、恢复播放和旧版对照已检查。
- 补充验证：浏览器白色背景检查、Python 编译检查与相关根文档的 `git diff --check` 通过；预览页、清单及三个 GIF 最终请求均为 HTTP 200。工具额度限制阻止了最后的标签页保留操作，可通过上述本地地址打开预览。
- 制作方法与边界已补充到项目 `mascot-to-gif` skill。应用资源未替换，视觉效果等待主人确认。

### 2026-09-10 Stage 1 原图保真动作修订（已生成，2026-09-11 已认可）

- [x] 对照正式 Stage 1 原始 PNG 与 v2 首帧，确认 v2 的新 atlas 在身体轮廓、眼睛高光、手脚体积、叶片颜色和短绒纹理上发生偏移；局部补洞试验版 v3 也确认会产生尖锐边缘伪影。
- [x] 改用正式运行 PNG 的完整原始姿态作为每个动作状态，统一一次归一化、移除底部地面影子，并通过整只角色的小幅刚体位移／倾斜补充节奏；没有重绘身体、拉伸躯干或逐帧改色。
- [x] 重新生成 A01、A02、A03 三个 16 帧 GIF、48 张透明 RGBA 帧、3 张 4×4 图集和关键帧联系图，输出至 `output/mascot-gif-stage1-pantomime-20260910-v4-rigid3/`；预览页独立运行，应用素材与旧预览保持不变。
- [x] 验证三个 GIF 均为 768×768、16 帧、`loop=0`，总时长 2400／2600／2800 ms，最小透明留白分别为 101／103／97 像素，四角透明且无底部影子；第 16 帧与第 1 帧使用同一原始姿态，仅保留 1 px 收势位移。
- [x] `http://127.0.0.1:8777/preview.html?fresh=rigid3` 已在本地浏览器加载，棋盘格透明背景、三张动作卡片和逐帧控件可见；主要预览资源 HTTP 200。
- [x] 2026-09-11 主人认可三个原图姿态切换样本，要求沿用其表现形式设计其余 47 个动作；尚未授权应用资源替换。

### 2026-09-10 Web 首次句子选择下限调整（已完成）

- [x] 正式 Web onboarding 从「必须正好 3 句」改为「至少选择 5 句」；达到 5 句后继续选择不再被前端上限拦截，控制器也允许保存全部已选种子句。
- [x] 开始操作栏、选择计数器、推荐按钮和提交校验已同步到新规则；推荐操作改为 5 句，计数器明确展示「至少 5 句」而不是暗示最大数量。
- [x] 简体中文、繁体中文和日语的标题、说明、计数器、推荐按钮及校验失败文案已同步更新；提交失败通过现有 legacy translation 按界面语言显示。
- [x] 新增并通过 5／6 句选择、少于 5 句拒绝、三语文案和界面提交回归测试；目标测试共 65 项通过，`flutter build web --release` 成功。
- 验证边界：`flutter analyze --no-pub` 仍报告项目原有 `admin_controller.dart` 的 2 条 `use_null_aware_elements` info；全量测试 183 项中有 4 项既有失败，分别是吉祥物语义标签和 `web_status_test.dart` 的旧默认语言断言，未涉及本次修改。

### 2026-09-10 Release 本地服务重启

- [x] `SelahFlutter/tool/serve_release.js` 支持命令行端口参数，默认端口仍为 5191；本次已在 5180 重启并验证 HTTP 200，加载最新 Web Build ID `89ba6d49a5b2a7b3`。

### 2026-09-10 Stage 1 毛绒默剧方向一（已生成，待审阅）

- [x] 按主人选择的方向一完成 [A01—A03 毛绒默剧 GIF 制作计划](docs/superpowers/plans/2026-09-10-stage1-pantomime-gif-plan.md) ，明确「偷偷打招呼」「憋笑露馅」「挥手差点失衡」三个独立片段的逐帧姿态、首版时长、输入输出、制作顺序及验收标准。
- [x] 根目录 `CLAUDE.md` 已记录本轮仅限计划的边界；后续需要补绘真实手势、眼神和脚步，以当前三个 GIF 为各自参考，保留透明背景、无地面影子及 12％ 留白。
- [x] T01—T05 已按顺序完成：锁定三个源 GIF 的参考首帧，补绘关键姿态，整理每个动作 16 帧，编码 GIF，拼接 4×4 图集并建立独立预览。
- [x] 新输出目录为 `output/mascot-gif-stage1-pantomime-20260910-v1/`，包含 A01／A02／A03 三个独立 GIF、48 张 RGBA 帧图、3 张 4×4 图集、manifest、验收记录和 `preview.html`；预览服务为 `http://127.0.0.1:8775/preview.html`。
- 最近验证：三个 GIF 均为 16 帧、无限循环、disposal=2，实际总时长分别为 2400／2600／2800 ms；每帧 768×768 RGBA，四角透明，最小边缘留白 93 像素以上；第 16 帧逐字节复用第 1 帧。没有修改当前 `8774` 预览、其它 47 个 GIF 或应用资源。
- 本轮写入：方向一制作计划的执行记录、关键姿态清理与帧组装脚本，以及独立预览输出；动作表现力仍待主人在新预览中确认。

### 2026-09-10 吉祥物图片转 GIF skill 与批量导出（已完成，可审阅）

- [x] 新增项目级可复用 skill：[mascot-to-gif](skills/mascot-to-gif/SKILL.md)；包含透明 GIF 编码、统一画布与比例、12％ 安全留白、低 alpha 中性地面影子清理、阶段合并、逐表情独立微循环、动态弹跳／摆动与表现力循环测试、逐帧来源清单和解码校验流程。
- [x] 将正式运行素材 `SelahFlutter/assets/sprites/PlushV4S1A01.png`—`PlushV4S5A10.png` 共 50 张按阶段转换为 5 个十帧 GIF，并生成一个 50 帧总览 GIF；原始 PNG 未修改。
- [x] 产物见 `output/mascot-gif-export-20260910-v7/`；6 个 GIF 均为 768×768、无限循环，最小边界留白 12.11％，透明角点和帧数校验通过；交互预览支持棋盘格、浅色、深色和珊瑚色背景，并列出 5×10 的完整帧编号清单。
- [x] 按主人确认的「一个表情一个 GIF」方案生成 `output/mascot-gif-individual-20260910-v2/`；5 个阶段各 10 个独立 GIF，共 50 个，每个 8 帧、160 ms／帧，HTML 按阶段展示全部文件；应用资源暂未替换。
- [x] 按反馈生成 `output/mascot-gif-stage1-dynamic-20260910-v1/`；仅 Stage 1 的 A01、A02、A03 使用更明显的动态循环（12 帧、100 ms／帧、弹跳／摆动／旋转／挤压伸展），独立预览页已启动，应用资源暂未替换。
- [x] 按进一步反馈生成 `output/mascot-gif-stage1-expressive-20260910-v1/`；仅 Stage 1 的 A01、A02、A03 使用表现力循环（16 帧、90 ms／帧、多频率弹跳／回弹／摆动／旋转跟随），独立预览页已启动，应用资源暂未替换。
- [x] 按进一步反馈生成 `output/mascot-gif-stage1-action-switch-20260910-v2/`；只基于现有三个表现力 GIF 重排关键帧，以保持／快速切换／峰值停留／回落收势形成动作切换感，三个独立 GIF 的逐帧时长与预览页已生成，应用资源暂未替换。
- [x] 按主人确认的动作跟随方向生成 `output/mascot-gif-stage1-layered-action-20260910-v2/`；只基于上述三个动作切换 GIF，为 A01、A02、A03 分别叠加无接缝的弹性弹跳／挤压／摆动／旋转／回弹，保留原有关键帧和停留节奏，三个独立 GIF 与联系图、预览页已生成，应用资源暂未替换。
- [x] 仅清理底部低 alpha、中性深色地面影子像素，没有新增影子；设计展示稿、历史图和合成图集按项目规范排除，未当作运行帧转换。
- 最近验证：`skill-creator` 的 `quick_validate.py` 通过；50 个独立 GIF 全部重新打开解码，均为 768×768、8 帧、`loop=0`，最小留白 13.67％，透明角点和微动帧校验通过；Python 编译检查、`git diff --check` 和浏览器深色背景检查通过。
- 最近验证：动态测试 3 个 GIF 全部重新打开解码，均为 768×768、12 帧、`loop=0`，最小留白 15.49％；预览页棋盘格与深色背景检查通过，动态参数与输出清单一致。
- 最近验证：表现力测试 3 个 GIF 全部重新打开解码，均为 768×768、16 帧、`loop=0`，最小留白 17.45％；预览页棋盘格与深色背景检查通过，表现力参数与输出清单一致。
- 最近验证：动作切换测试 3 个 GIF 全部重新打开解码，均为 768×768、14～15 个状态、`loop=0`，最小留白 17.45％；基准 80 ms、关键状态更长停留，预览页棋盘格与深色背景检查通过。
- 最近验证：弹性动作跟随测试 3 个 GIF 全部重新打开解码，均为 768×768、14～15 个状态、`loop=0`，最小留白 16.67％；A01／A02／A03 总时长分别为 1700／1580／1720 ms，透明角点、无地面投影、联系图和 `8774` 预览页加载检查通过。
- 限制：现有 A01—A10 是独立产品姿态的展示顺序，不等于连续中间帧动画；GIF 是预览／展示派生物，正式产品继续使用 RGBA PNG 母版。本轮未接入应用、未安装新依赖、未修改配置或部署。

### 2026-09-10 笔记 B1＋B2 UI／UX 与产品实施（核心实施与本地构建完成，真机验收待补）

- [x] 完成 [笔记 B1＋B2 设计](docs/superpowers/specs/2026-09-10-notes-b1b2-design.md) 、[方案对照](docs/superpowers/specs/2026-09-10-notes-b1b2-ui-overview.png) 、[网页稿](docs/superpowers/specs/2026-09-10-notes-b1b2-ui-desktop.png) 、[手机三状态稿](docs/superpowers/specs/2026-09-10-notes-b1b2-ui-mobile.png) 和 [开发计划](docs/superpowers/plans/2026-09-10-notes-b1b2-plan.md) 。方向为完整双语卡片、原卡片展开拆解、已有词汇点开释义；取消截断英文和空详情栏。
- [x] 已确认实施范围：只改正式 Web 笔记页和对应测试／文档；成长回忆入口保持隐藏；未新增数据表、云端字段、依赖、密钥、CI 或部署。
- [x] T00—T05 已完成：失败测试、三语笔记文案、完整双语卡片、原卡片拆解多开、已有词汇点选面板、搜索／分类空状态与会话内返回状态。
- [x] T06 的 Widget 级视口与 200％文字检查已完成；按钮使用文字标签，词汇片段可通过 InkWell 获得键盘焦点和 Enter／Space 激活语义。
- [x] 最终本地命令：`flutter analyze --no-pub` 无错误、`flutter test --no-pub` 全量 181 项通过、`flutter build web --release` 成功；详见 [笔记 B1＋B2 验收记录](docs/notes-b1b2-acceptance.md) 。
- [x] 为避免本地旧 Service Worker 继续命中旧笔记界面，已按标准脚本重新生成 Web 资源；本次 `selah-build-id` 为 `89ba6d49a5b2a7b3`，并在无旧缓存的本地 Release 页面确认新版笔记卡片已显示。打开已有页面时需刷新或应用可用更新。
- [ ] 真实浏览器视口、iPhone Safari／Android 真机仍待补验；Widget 测试已覆盖逻辑尺寸和 200％文字。全项目 analyzer 保留 2 条既有 admin info；未执行公开部署。工作区另有与本任务无关的既有改动，本任务未覆盖。
- 本轮写入：笔记 UI 实施、笔记专项测试、正式入口回归测试、三语文案、验收记录和本节路线图。
### 2026-09-10 会员、试用与费用保护规划（方案与展示交付完成，产品未实施）

- [x] 完成 [会员／试用／费用保护设计](docs/superpowers/specs/2026-09-10-membership-cost-control-design.md) 、[独立交互展示稿](docs/superpowers/specs/2026-09-10-membership-cost-control-ui.html) 和 [分阶段开发计划](docs/superpowers/plans/2026-09-10-membership-cost-control-plan.md) 。产品方向为免费示例、7 天限额试用、39.9 元月会员；购买前展示完整静态权益，日常不展示剩余额度。
- [x] 已将「只做设计与计划、先不改产品代码」写入 CLAUDE.md 与 SelahFlutter/CLAUDE.md。GPT 来源说明、权益与模型费用原子预占、支付到账、平台预算与资源保护列为实施前验证门槛，不构成本轮执行授权。
- [x] 2026-09-11 完成交付核对，补齐 [方案总结与八张界面图片索引](docs/superpowers/specs/2026-09-11-membership-delivery.md) 及会员开通成功截图；前七张历史图片补充正确 JPEG 后缀副本，画面字节一致，原链接保留。
- [ ] 产品开发：计划 T01—T10 全部未勾选；新的代码实施授权到位后再进入费用上界证明、账务预占、生成入口接入、支付、资源保护、会员 UI、管理员核查与 A01—A12／G01—G05 验收。
- [ ] 上线门槛：转写费用上界、完整权益可履约、支付渠道、试用 2 元／会员每账期 20 元模型预算、存储／流量与基础设施预算待确认。2 元／20 元不是已保证的最高总账单。
- 最近验证：2026-09-11 交付文件本地链接和展示稿脚本语法检查通过；八张 JPEG 均可解码，前七张副本与原文件字节一致；复看方案／配音上限／开通成功画面，浏览器模拟付款核验到开通成功流程通过。此为文档与展示验证，不代表 A01—A12／G01—G05 产品验收已通过。
- 本轮写入：规范、设计、实施计划、独立展示稿、界面图片、交付索引及本节。未修改产品代码、测试、构建、依赖、数据库、支付或部署；工作区另有与本任务无关的既有改动，本任务未操作。

### 2026-09-10 设置、三语界面与 PWA 能力（核心实施完成，合并方案已收口）

- [x] 完成 [设置／语言／本机能力设计](docs/superpowers/specs/2026-09-10-settings-language-pwa-design.md) 、[界面语言计划](docs/superpowers/plans/2026-09-10-interface-language-plan.md) 与 [设置／PWA 计划](docs/superpowers/plans/2026-09-10-settings-pwa-plan.md) 。语言设置最终合并为一个“母语”三选一控件：`zh-Hant` 繁体中文、`zh-Hans` 简体中文、`ja` 日本語；默认 `zh-Hant`。界面 locale 由该选择派生；学习语言恢复英语／日本語双选项，英语可用，日本語灰色禁用并标注「之後準備加入」；保护、安装、更新仍按真实状态呈现。
- [x] 使用现有 Flutter／Dart 能力完成单一 `nativeLanguage` 偏好、三语文案表与运行时切换；`uiLocale` 只保留兼容读取，不再写入快照。两个中文选项共用中文生成／转写路由，日本語使用 `ja` 路由。
- [x] 完成日语输入的生成、整理、转写语言路由，以及循环聆听的母语／目标语言标签与三语操作文案；旧双字段快照可迁移，本机选择在同步／备份合并时保留。
- [x] 完成设置页语言区、提醒／账户／备份／离线／设备／应用分区；本机存储保护、安装到主屏幕、检查更新与显式应用更新均按真实平台状态呈现，并在录音或未保存状态下保护高风险操作。
- [x] 完成 PWA 繁中元数据、离线资源与 Service Worker 显式更新流程，加入全局更新提示和安装状态反馈。
- [x] 未新增 `flutter_localizations`／`intl` 或字体依赖，沿用现有字体回退；未修改数据库 schema、migration、密钥、CI 或部署配置。
- 最近验证：统一语言的模型、设置 Widget、文案和中文／日语路由目标测试已通过；Flutter 全量回归和 Release Web 构建已在本节后续复核记录。Deno 测试因环境未提供 `deno` 命令暂未执行；iOS Safari／Android 真机安装更新仍待设备验收。
- 2026-09-10 合并方案复核：`flutter test --no-pub` 全量 187 项通过；`flutter analyze --no-pub` 无 error，仅有 `admin_controller.dart` 两条既有风格 info；Node 桥接／Service Worker／循环听目标测试 23 项通过；正式 `tool/web.ps1 -Action build` 成功并生成 Build ID `da3f3e99e590825f`。本地 5180 服务已返回该构建，浏览器更新后设置页实测显示「母語」三选一，以及英语可用、日本語禁用的学习语言双选项。
- 2026-09-10 学习语言控件调整：设置页恢复英语／日本語双选项，英语保持当前可用，日本語以灰色禁用态显示「之後準備加入」；目标语言合约继续固定 `en`。设置／三语文案定向测试 27 项与 Flutter 全量 187 项通过，Release Web 构建生成 Build ID `1bc08ba573287dff`，浏览器实测已加载最新控件。
- 本轮写入：本节、语言模型与本地化资源、设置／循环聆听 UI、控制器与浏览器桥接、日语服务端提示词及对应测试；工作区另有与本任务无关的既有改动，未作为本轮交付范围处理。

### 2026-09-10 循环听本地实现（核心代码接入，真机与母语音频待验收）

- [x] 基于主人认可方向完成 [UI／UX 设计](docs/superpowers/specs/2026-09-10-loop-listening-design.md) 、[静态界面总览](docs/superpowers/specs/2026-09-10-loop-listening-ui.png) 、[矢量设计稿](docs/superpowers/specs/2026-09-10-loop-listening-ui.svg) 和 [整体开发计划](docs/superpowers/plans/2026-09-10-loop-listening-plan.md) 。覆盖桌面设置／播放、手机播放、自定义时长、准备／暂停／错误／结束和跨页迷你播放器。
- [x] 已将本轮“只做设计与计划、先不改代码”写入 `CLAUDE.md`。方案按完整未归档句库逐句双语循环，默认学习语言后母语，可反向；支持 15／30／60 分钟及 1～720 分钟自定义；循环播放与学习完成／成长奖励隔离。
- [x] 已接入循环设置模型、语序／1～720 分钟时长偏好、正式「聆听」模式切换、桌面设置／播放卡片、手机布局、自定义时长弹层、跨页迷你播放器、账户切换终止旧会话，以及普通播放／试听／录音开始前暂停循环。
- [x] 浏览器音频层新增独立 `audioLoop*` 会话，覆盖学习语言／母语成对播放、1／2 秒间隔、跨轮、待生效语序、固定截止时间、暂停期间倒计时继续和旧会话隔离；循环音轨不写 `listen_completed`、复习状态或成长奖励。
- [ ] 母语音频真实库存、样本试听、预制预算以及 Safari／PWA／Android 锁屏与 60 分钟长时截止验收。当前未调用 TTS，未生成母语音频，未做真机验证；本地逻辑不能代替这些证据。
- [ ] Flutter Widget／全量测试与 Release Web 构建待执行。当前环境下 `D:\setup\flutter\bin\flutter.bat test` 无输出且日志为 0 字节；因此未把 Widget 测试或构建标记为通过。
- 最近验证：`dart analyze lib/web` 与新增 Dart 测试文件无错误（仍有 3 条既有 info：管理后台 2 条 null-aware、本地化占位 1 条）；`node --check web/selah_bridge.js` 通过；`node --test test/browser_loop_playback.test.mjs` 4 项全部通过。未改依赖、数据库、CI、密钥、配置、服务端或部署。
- 本轮写入新增循环模型、UI 面板、控制器与桥接代码及新增测试；工作区存在与本任务无关的管理后台和其他并行改动，未作为循环听完成项处理。

### 2026-09-10 暂时隐藏成长回忆入口

- [x] Web UI 暂时隐藏「成长回忆」笔记卡片、「打开回忆册」按钮和宽屏陪伴栏的回忆摘要／「查看全部回忆」入口；保留回忆事件、本地数据、云同步和弹层实现，后续只需重新打开 `SelahFlutter/lib/web/ui/web_learning_app.dart` 中的 `_growthMemoriesUiEnabled` 开关恢复入口。
- 最近验证：先以两个 Widget 测试复现入口仍可见的失败，再完成实现；`flutter analyze --no-pub` 0 issue，`flutter test --no-pub` 141 项全部通过。标准 Release Web 构建成功，新 Build ID 为 `818ec9378df88fcb`；编译产物 `main.dart.js` 已无「成长回忆」「打开回忆册」「查看全部回忆」UI 文案。未调用外部 API，未改数据库、密钥、CI 或远端部署。

### 2026-09-09 Web 改善实现、函数部署与发布候选

- 当前决定：维持 `gpt-4o-mini-transcribe`、`gpt-4o-mini`、`tts-1` 及现有声线、MP3、Supabase Storage 和音频缓存；低价替代方案仅存档，不进入本轮开发。费用调研、13 项改善设计与实施计划分别见 [费用调研](docs/2026-09-07-web-ai-cost-research.md) 、[改善设计](docs/superpowers/specs/2026-09-07-selah-web-improvement-design.md) 和 [实施计划](docs/superpowers/plans/2026-09-07-selah-web-improvement-plan.md) 。
- [x] T01 输入草稿与异步保护：正式 Today 输入和分段编辑接入控制器并按账户持久化；刷新恢复，生成成功只清理未再编辑的提交版本，等待期间的新编辑不被旧结果覆盖；空分句在请求前阻止。
- [x] T02 长文本完整分批：`PreparationDraft`／`PreparationSegment` 纳入本机快照、备份、账户隔离与合并；整理最多保留 20 段，生成每批 5 段，成功段落保存，失败只重试剩余段，刷新可恢复。
- [x] T03 输出合约：单句、整理和批量统一英文非空且 ≤1000、词汇最多 3、六类分类、输出预算 2048／4096／8192；截断、非法分类、缺字段和分段 ID 异常均安全失败。
- [x] T04 相同句子复用：当前账户、相同中文原文、已知模型／prompt 版本和语言一致时直接打开现有记录，供应商调用为 0；主动「重新生成」使用新请求 ID，复习进度和音频引用保留。
- [x] T05 音频恢复：进行中任务 TTL 复用、过期任务从 Storage 恢复、并发单认领、上传有界重试、签名失败不重新合成均有替身测试覆盖。
- [x] T07 转写注册与单函数部署：`supabase/config.toml`、`deploy-full.sh` 与部署合约测试统一包含 8 个函数；`speech-transcribe` 已部署到 `ijonabyyppmgvoufgamt`，部署后 `OPTIONS 200`、无凭证 `POST 401 UNAUTHORIZED_NO_AUTH_HEADER`。未改 migration、secret 或其他函数。
- [x] T07a 生成与音频改善部署：主人批准后，`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 已逐一部署到同一项目；四个函数均为 `OPTIONS 200`、无凭证 `POST 401`。部署后只读取回远端源码，16 个 TypeScript 文件（入口与共享模块）与本地 SHA-256 全部一致；未调用 OpenAI，未执行数据库或 secret 变更。证据见 `output/remote-function-postdeploy-20260909-114811/postdeploy-shared-verification.json`。
- [x] T08 四声线种子音频：远端 120 条 ready（30 句 × 4 声线）已全部取回；本地包包含 120 个 MP3、12,529,440 字节。逐文件 SHA-256、字节数、Release 副本一致性及 FFmpeg 完整解码均为 120／120；Chrome 离线读取／哈希全部通过，四声线抽样解码成功，新增 TTS 调用为 0。逐文件证据保存在 `output/playwright/final-web-acceptance/seed-audio-verification.json`。
- [x] T11 本地发布候选：最新 Release Build ID 为 `1c0036e1c11f90a9`，231 个文件、99,789,958 字节；完成预缓存精简后的正常／通用 CanvasKit 离线重开与两轮各 120 段音频校验。前序 `7e0a4516b041c795` 的 Today 草稿恢复、桌面／手机布局与完整解码证据仍保留；最新改动仅为 Service Worker。完整记录见 [Web 改善验收](docs/web-improvement-acceptance-2026-09-09.md) 和 [首装性能验收](docs/web-performance-2026-09-09.md) 。
- [x] T10a 本地首装性能优化：依据实际构建配置与 Edge 网络记录，移出 8 个未启用渲染器的固定预缓存条目，保留两种 CanvasKit 和全部 120 段音频。实测缓存从 73,515,852 降至 56,847,959 字节，减少约 22.7％；两种渲染器的离线重开均通过。此项仅为桌面浏览器实验，T10 真机／生产网络仍未完成。
- [x] 部署辅助脚本收尾：默认预演完全离线，执行时复用 CLI 登录或进程 token，以固定项目路径仅部署转写函数，强制检查 `OPTIONS 200` 和无凭证 `POST 401`；6 项本地替身测试通过。此脚本修正未触发再次部署。
- [x] T09 验收脚本费用保护收尾：将第二普通账户登录与已有句子／事件 RLS 样本检查移到首次付费接口之前；先复现 6 类错误在旧脚本中已发送 10 次业务请求（含重放），修正后均为 0 次。22 项验收脚本测试与 200 项 Deno 全量测试通过，dry-run 未联网；真实账户验收仍待执行。已同步 [后续工作与完成标准](docs/next-development.md) ，并明确接口请求数不能代替供应商实际费用。
- [x] 四函数部署准备：最小范围与风险操作单已归档；只读备份现有 `sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 到 `output/remote-function-baseline-20260909-111153/`。4 个入口、24 个文件及其 SHA-256／字节数全部验证通过，未改变远端函数。
- [ ] T06 使用量统计：统计设计已归档于 [使用量统计设计](docs/2026-09-08-generation-usage-design.md) ，但 `generation_usage_attempts` migration、服务端写入和汇总尚未实施；数据库 schema 需单独确认。
- [ ] T09 真实链路：五个本轮涉及的远端函数部署和零费用鉴权检查已完成；T09 脚本与五个函数请求／响应合约逐字段对齐，`deno check` 与 dry-run 通过，执行手册见 [真实远端验收说明](docs/remote-acceptance.md) 。普通测试账户与真实中文录音尚未提供，进程环境和 `.env` 均未发现相关变量。真实 AI／TTS／转写、RLS 与跨设备仍未验收，继续沿用已确认调用预算。
- [ ] T10 真机与发布：iPhone Safari／主屏幕 PWA、Android、实体麦克风、软键盘、低速网络、安装更新、性能和生产 HTTPS 尚未验收；当前 Chrome 手机视口不等于真机。
- [ ] T12 Web Push：维持暂缓，需独立订阅表、RLS、VAPID 与调度确认。
- 最近验证：本轮重跑 `flutter analyze --no-pub` 0 issue、Flutter 140 项、Node 21 项、Python 5 项、Deno 194 项全部通过；Deno lint 30 个文件、8 个函数及 2 个脚本类型检查通过；PowerShell 部署辅助脚本 6 项通过，实际默认 dry-run 也通过；远端验收 dry-run 未联网／未计费。既有 Release `7e0a4516b041c795` 的 120 段四声线 MP3 全部通过哈希、副本及完整解码复核；原 Chrome 离线验收 120 段哈希匹配、四声线抽样解码成功、控制台 0 错误。五个改善函数部署后的零费用路由检查均通过，远端与本地 16 个 TypeScript 文件哈希一致。
- 2026-09-09 续作验证：本次仅修改远端验收脚本、测试和交付文档；Deno 全量由 194 项增至 200 项并全部通过，受影响两文件 lint 与默认 dry-run 通过。再次核对 120 段音频的源文件 SHA-256／字节数、Release 副本及预缓存清单，失败为 0；证据见 `output/playwright/final-web-acceptance/seed-audio-current-integrity.json`。Web 代码与构建未变化，沿用上述 Flutter／浏览器证据，不把它们写成本次重新执行的结果。
- 2026-09-09 性能续作验证：Node 浏览器测试由 21 项增至 22 项并全部通过，`flutter analyze --no-pub` 无 issue、`flutter test --no-pub` 140 项通过、Release 重建通过。新候选的两个全新 Edge 上下文分别自动选择 Chromium 与测试强制通用 CanvasKit，均离线重开成功、120 段音频哈希匹配、浏览器未捕获异常为 0。原始记录为 `performance-candidate.json` 与 `performance-candidate-full.json`；未运行付费样本、迁移或公开发布。
- 2026-09-09 GIF 可行性调研：以 S1 的现有姿态图为参考，使用内置 `imagegen` 生成两版 4×4／16 帧飞吻精灵图，并用本地切帧脚本合成 313×313、约 90ms／帧的循环 GIF；同时将 S1 现有十姿态合成对照 GIF。结论为原型可行，但模型存在格间越界、留白不足和嘟嘴形似数字「3」等问题，生产素材仍需边界校验、统一缩放及确定性文字叠加；未接入产品动画运行路径。证据见 `output/mascot-gif-test-20260909/`。
- 边界：`speech-transcribe` 与四个生成／音频改善函数已远端部署；未执行数据库 migration，未修改 `.env`／secret／CI，未调用 OpenAI，未公开发布 Web。

### 2026-09-07 Web 页面操作与可靠性闭环（已通过验证）

- [x] 完成整体页面操作与 UI/UX 改善方案验证：修复转写替换撤销与长度限制、两段式开口自评（暂存、撤销、保存离开提示）、笔记中英文复制反馈、引导页精灵阶段适配与移动端列表详情平稳回退；Flutter analyze 零 issue，SelahFlutter 115 项全量测试全部通过，Node 浏览器测试 14 项全部通过，Release Web 构建成功（Build ID: c006900cd4c2403d），本地 5191 静态服务已启动并可正常访问。

### 2026-09-07 透明精灵与 Today 居中修订（进行中）

- [x] 按主人选择用本地脚本从五十张原始设计图导出真实 RGBA 运行素材，原图保留；验证空白透明、轮廓完整和动作一致（768x768 RGBA，体积从 68.73 MiB 缩减至 21.7 MiB）。
- [x] 欢迎区撑满内容宽度，精灵、名字与状态、标题及说明居中；移除顶部小精灵，Today 宽屏保留单一精灵焦点，调整输入区与例句间距。
- [x] 完成布局回归测试、素材校验（Node 19项全过）、Flutter 静态分析零 issue、Today 窄屏大字排版适配、Release Web 构建完成并启动 5191 服务多视口浏览器复验通过。

### 2026-09-07 精灵主页布局调整

- [x] 精灵展示位置重构：将主页右上角 52px 小头像调整为主问候语上方居中，尺寸调整为 140px，使其更显眼、更容易被用户第一时间感知。
- [x] 精灵状态即时呈现：在精灵下方增设名字与状态胶囊（如「小芽 · 慢慢来，就很好。」），实时展示当前学习状态与对应动作姿态。
- [x] 问候语文本与层级解耦：主标题规范为「今天，想说点什么？」，避免将精灵昵称混同为用户称谓。
- [x] Flutter Web 重新构建与浏览器验证通过：dart analyze 零 issue，全套 Node 桥接及姿态测试 17 项全部通过，Release Web 构建完成，真实浏览器（127.0.0.1:5191）渲染验证无异常。

2026-09-06 UI／UX 后续：主人认可整体审查并授权完整改造；详细设计见 `docs/superpowers/specs/2026-09-06-selah-web-ux-reliability-design.md`，实施计划见 `docs/superpowers/plans/2026-09-06-selah-web-ux-reliability.md`。本机已完成输入草稿、诚实同步状态、录音转写安全、跨页迷你播放器、手机详情层、练习显式保存、成长进度、笔记操作与登录表单反馈；`analyze --no-pub lib/web` 无 issue，Flutter 90 项、浏览器桥 13 项测试通过，Release Web 构建成功。Supabase DNS 已恢复，认证入口返回 200；服务端只读精确计数为 30 条 seed、120 条 ready 种子音频清单、0 条用户句子、1 条学习事件。真实登录、生成、转写、普通用户同步与跨设备验收仍未完成，不能以只读计数或本地测试替代。

2026-09-06 C 角色交付：五阶段各十张独立动作图共 50 张已生成并核验，正式 Web、Flutter 共享展示组件和 Gallery 已采用阶段／动作映射；首次见面显示第一阶段，完成引导后进入第二阶段，待机支持短暂眨眼与轻摆。79 项 Flutter、17 项 Node 测试及两个 Release 构建通过；正式版本为 `bcd6314a55cb0fac`，预览为 `c774a8589cee3d2f`。原 `5181` 站点已应用新缓存并实证加载 S1 新素材。完整证据见 `docs/web-plush-50-acceptance.md`。

2026-09-06 的历史素材基线为 50 张带暖白背景的 RGB PNG，合计 68.73 MiB；2026-09-07 已按主人选择导出真实 RGBA 运行素材，当前合计约 21.74 MiB。多尺寸发布优化按实测需要开展，真实手机性能仍待验收。旧 Flutter 原生页面的固定阶段、学习事件成长及服务路径仍是保留客户端待办，共享角色展示更新不代表原生产品端到端完成。2026-09-05 的旧图集与 `c09b325e7f7fb159` 仅为历史基线；下方 iOS／Flutter 记录保留原验证日期，不代表当前远端状态。

### Web 开发进度

- 最新交付：主人确认的五阶段 V3 外形已扩展为五十张正式姿态，并完成本地程序展示和 Web 接入；计划见 `docs/superpowers/plans/2026-09-06-seed-plush-50-implementation.md`，五阶段总览位于 `design-system/selah/mascot/seed-c-actions-v4-all-review.png`；未进行公开部署。
- [x] C 第一阶段视觉 V2：十张独立 PNG 姿态，包括蜷坐、伸展、侧耳、坐听、致意、开口、拍手、腾空小跳和低位邀请；第十张小布手轮廓已局部修订，文件完整性与复制哈希检查通过。
- [x] 五阶段 V2 历史提案：完成对照图及五十格动作矩阵草案；其中第三至第五阶段未采用，最新外形以 V3 确认稿为准。
- [x] 主人确认第一阶段十个动作；保留现有十张设计图。
- [x] 第三至第五阶段 V3 静态外形：绿叶、花苞、开花三张通过图片核验，主人已认可效果；本轮统一五阶段时原图保留。
- [x] 2026-09-06 第一、第二阶段 V3：完成小折芽和低矮双叶两张独立 PNG，统一五阶段短绒材质与角色特征；五图解码、尺寸与色彩类型、原件复制哈希通过，第一阶段十动作及后三阶段原图哈希不变。
- [x] 主人确认五阶段统一外形，并授权五十动作图生成及程序／网站接入。
- [x] 五阶段各十张正式动作图：50 张均为 1254 × 1254 RGB PNG，唯一 SHA-256、manifest、设计／运行副本及目视检查通过；完整总览已生成。
- [x] Web 真实阶段／动作映射、短暂过渡、待机眨眼／轻摆、业务动作优先、Reduce Motion、后台暂停、预热失败重试和并发合并；Flutter 共享展示与五阶段 Gallery 同步更新。
- [ ] C 发布性能与设备验收：透明导出与本轮压缩已完成；根据首屏、阶段切换及内存实测决定多尺寸优化。iPhone Safari／Android 真机及生产 PWA 更新仍待完成。

- 当前实施：五十姿态本地交付后转向发布素材优化、真实服务与设备联调。最新证据见 `docs/web-plush-50-acceptance.md`；以下 2026-09-05 旧图集条目保留为历史开发记录。

- [x] 2026-09-05 角色方向确认：当前阶段采用 C「短绒织物」；D「磨砂琥珀」保留为未来其他吉祥物候选，不在本阶段开发。
- [x] C 设计交接包：角色设定、十状态参考与 C 单独页面效果三图已整理，目视、PNG 完整性与复制哈希检查通过；查看 `design-system/selah/mascot/current-c-design-pack.md`，后续清单见 `docs/next-development.md`。
- [x] 2026-09-05 吉祥物 V4：按用户选择完成短绒与磨砂琥珀两款深化形象、各四种状态及学习页面静态模拟；三张 PNG 目视、完整性与复制哈希检查通过，运行资产未定稿。
- [x] 2026-09-05 吉祥物 V3：完成软胶、陶瓷、短绒、磨砂琥珀四种候选并核验，每款含主形象与专注／开心状态；用户选择 C／D 继续深化，未接入 Web。
- [x] 2026-09-05 吉祥物 V2 视觉修订：按原始 Seed C 版完成标准图与十状态效果图并核验，交付位于 `design-system/selah/mascot/`；用户后续反馈质感不合适，未采用，现保留为历史稿。
- [x] C Web 运行接入：同一短绒图集、固定眼位／叶根／身体比例，Flutter 轮廓裁切和原生刺绣五官，五个成长阶段沿用现有记录；引导、手机陪伴位、头像和桌面栏已替换并目视检查。
- 2026-09-05 历史素材要求已被替代：旧 RGB 图集的身体／叶片分层导出不再作为当前交付任务；现按已批准的五十张独立动作图使用真实 RGBA 运行素材，完成证据见 2026-09-07 记录。
- [x] C Web 十动作：闲置、眨眼、叶摆、播放准备／播放中／真实完成、录音／转写结果、复习反馈已接线；一次性反馈归位、事件幂等、取消／失败、Reduce Motion 和后台停止通过验证。
- [x] 圆形悬浮开始操作：64px 按钮，姓名／恰好三句／忙碌校验，数量提示、键盘激活、滚动固定、窄屏布局、失败提示可见性通过验证；实体手机软键盘仍归入设备验收。
- [x] C 真实效果预览：开发入口 `tool/preview_plush.dart` 使用同一正式组件，展示十动作与五个成长阶段；构建脚本支持 `-PreviewPlush`，Release 构建与浏览器显示通过。
- [x] 本轮收尾：矮窗口陪伴栏可滚动且回忆按钮固定、累计成长文案准确、开始操作无重复语义、启动页不闪旧角色；全量 Flutter／浏览器桥测试通过。
- [x] Web 条件入口、账户隔离的 IndexedDB、30 条真实 seed 文本与音频基线；2026-09-09 候选已扩展为 30 句 × 4 声线共 120 段 MP3。
- [x] Supabase 认证、生成／整理／TTS 客户端合约与失败处理；本地替身测试通过，未声称真实服务已验收。
- [x] Today、Listen、Practice、Notes、Settings 和 Onboarding 页面及交互；Flutter 测试与浏览器核心流程通过。
- [x] 复习调度、词汇掌握、精灵回忆与成长；完成媒体播放后才记录聆听。
- [x] 同步冲突／账户隔离的本地测试、备份导入导出、文本草稿重试与音频校验缓存。
- [x] MediaRecorder 录音与权限失败处理；真实浏览器模拟音频设备验证，不等同于实体麦克风验收。
- [x] 新增 `speech-transcribe` 服务源码、幂等／额度合约与 Deno 测试；2026-09-09 本地配置与远端单函数部署均已完成，部署后零费用检查为 `OPTIONS 200`、无凭证 `POST 401`。
- [x] PWA 应用壳、显式更新、离线启动与前台提醒适配；本地浏览器记录保留验证通过。
- [x] 最终离线按钮资源修复后的 Release 构建与浏览器复验；无运行时错误，离线首次点击使用缓存着色器。
- [x] 2026-09-06 Web UX reliability：未提交输入和分段草稿按账户本机保存；同步状态区分本机保存／失败、同步中／失败、离线、待同步与已同步；转写结果不再直接覆盖原文，支持插入、显式替换、取消、重试和放弃；聆听／笔记窄屏改为列表→详情，跨页迷你播放器可用；练习评分必须显式保存并可撤销；成长进度不再按 15 次取模回退；登录弹窗补字段校验、密码可见与找回密码入口；笔记支持复制中英文和明确词汇状态。
- [x] 2026-09-06 Web UX 验证：`dart flutter_tools.snapshot analyze --no-pub lib/web` 无 issue；`dart flutter_tools.snapshot test --no-pub` 90 项通过；`node --test test/browser_bridge.test.mjs` 13 项通过；`powershell -NoProfile -File tool/web.ps1 -Action build` 成功构建 `build/web`。证据见 `docs/web-ux-reliability-acceptance-2026-09-06.md`。
- [ ] 后端已恢复可达；继续验证真实登录、AI、TTS、转写、跨设备同步及剩余种子音频。
- [ ] Web Push 服务端订阅／调度实施；设计已整理在 `docs/web-push-plan.md`，需独立 schema／配置授权。
- [ ] 旧 iOS 本地 SwiftData 历史导出适配及迁入验收。
- [ ] 线上部署与 iPhone Safari 验收（需独立记录环境证据）。

Web 基线见 `docs/web-acceptance.md`，C 角色最新证据与命令见 `docs/web-plush-50-acceptance.md`；运行方式见 `SelahFlutter/README.md`；剩余开发、联调与发布任务见 `docs/next-development.md`。

非动画系统的代码内实施已完成；首批 10 个原生 SwiftUI 精灵动画已完成代码接线，素材分层、柔和眼神和 Debug Gallery 入口收口修正也已通过 CI。长语音准备接口的部署清单、专用配额和幂等账本已补齐并通过 CI。第二阶段已完成远端 migration、7 个 Edge Functions 部署和 30 条 seed 导入；真实翻译验收因 `.env` 中 OpenAI key 返回 401 而暂停。真实 iOS 17+ App target、认证、AI／音频运行路径、学习数据闭环、Widget、原子生成额度及 SwiftData 版本迁移均已接线；真机视觉和发布材料仍属于外部环境验收。

## 已验证基线

| 项目 | 层级 | 证据 |
|---|---|---|
| Swift 核心模型、仓库、推荐、复习、可靠性模块 | 核心层已验证 | GitHub Actions run `29339236287`：227 tests，1 skipped，0 failures |
| Supabase schema 与 Edge Function 源码 | 本地数据库层已验证 | 4 个 migration、5 个 Edge Functions；临时 Supabase 的 pgTAP 与并发测试通过，当前未重新执行远端部署 smoke test |
| Seed 内容 | 内容已验证 | `v8.2`，30 句，6 类各 5 句，无重复 ID、无空核心字段 |
| 动画参考 | 样片存在 | 3 个 HyperFrames MP4 与 10 动作审阅片；已批准改为静态分层精灵 + SwiftUI 原生微动效 |

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

### 2026-08-03 Layered sprite pilot（已批准方向）

- [x] 主人批准方案 A：静态分层精灵 + SwiftUI 原生微动效。
- [x] 设计规范写入 `docs/superpowers/specs/2026-08-03-pet-layered-sprite-pilot-design.md`。
- [x] 素材工程化：9 个动作姿态 PNG（1x/2x/3x）、闭眼覆盖层与 12 帧姿态序列已生成并进入 `Assets.xcassets`。
- [x] 建立 `Assets.xcassets` 与 `PetLayeredArtwork` 静态渲染层，`PetSpriteView` 已切换为分层渲染并保留原生装饰与状态光环。
- [x] 完成 10 个动作的渲染映射、Debug Gallery 与分层素材单元测试代码。
- [x] 完成 Swift 测试、iOS 模拟器 Release 构建与无签名归档；GitHub Actions run `30756448030` 四门禁全绿。
- [x] 修正身体姿态素材，移除源 SVG 叶片和中性滤镜阴影，保持成长装饰由 SwiftUI 原生层负责。
- [x] 将 `quiz-fail` 与 `rec-done` 接入 `SeedEyesSoft`，并覆盖 Reduce Motion 表情退化。
- [x] 从 Debug 设置入口接入 10 动作 Gallery，确保 Release 导航不包含该入口。
- [x] 对上述收口改动重新执行 Swift、iOS archive、Supabase Deno、migration／concurrency 四门禁；GitHub Actions run `30813697889` 全部成功。
- [ ] 完成真机视觉、性能与 Reduce Motion 验收。

### 2026-08-11 收尾与默认语音准备

- [x] 推送文档提交 `90781cb` 至远端分支；GitHub Actions run `31405928557`（HEAD `90781cb`）全部成功。
- [x] 创建 draft PR `#1`（`codex/complete-non-animation-systems` → `main`），待主人审阅后合并。
- [x] 确认远端 seed 音频已完整：`audio_manifests` 120 条 ready（30 句 × 4 声线，含默认声线 `gentle-natural` 30 条），Storage 120 个 MP3 全量验证通过（下载 200、MP3 头有效、字节数与 manifest 一致、SHA-256 120/120 匹配）；生成时间 2026-07-11。
- [x] `seed_audio_prebuild.ts` 支持 `--voice` 参数按声线过滤（dry-run 已验证 30 句 × `gentle-natural` 计划）。
- [ ] 真机验收默认声线试听与 Onboarding 预取 3 句音频播放。

### 2026-08-11 OpenAI / Supabase key 现状（待主人确认）

- `.env` 中 `OPENAI_API_KEY`（`sk-proj-` 前缀）已失效：`/v1/models` 返回 401 `invalid_api_key`。
- 用户环境变量 `OPENAI_API_KEY` 有效（`/v1/models` 200，130 个模型）；若后续需要生成新音频（用户句子、日语等）可直接使用。
- `.env` 中 `SUPABASE_SERVICE_ROLE_KEY`（`sb_secret_` 新格式）有效，但仅能通过服务端 SDK（supabase-js）使用，浏览器直连 REST 会被网关以「Forbidden use of secret API key in browser」拒绝；`SUPABASE_ACCESS_TOKEN` 已失效（管理 API 401）。

### 2026-08-11 Flutter 客户端基线（代码完成，待平台验收）

- [x] 新建 `SelahFlutter/` 独立 Flutter 工程（Flutter 3.44.9 / Dart 3.12.2），iOS + Android target；现有 SwiftUI 工程与 Supabase 未做任何修改。
- [x] 建立 Selah 品牌设计系统：暖米色 token（`#FBF8F4` 背景、珊瑚 `#E06B54` 主色、薰衣草／鼠尾草／琥珀輔色）、Plus Jakarta Sans 字階、4pt 間距、圓角與陰影、動效時長與 Reduce Motion；決策記於 `design-system/selah/MASTER.md` 與 Flutter 內部 token。
- [x] 建立 Domain 層：實體、Repository 介面、領域枚舉（與 Swift 側字符串值一致）、`GenerateSentenceUseCase`／`GenerateAudioUseCase`／`ListenUseCase`。
- [x] 建立 Data 層：SQLite V1–V3（SwiftData V3 對應）、Repository 實作、DTO 契約、`FixtureSelahApiClient`（離線、不產生 TTS 費用）。
- [x] 建立頁面：Onboarding（命名＋3 句選取）、Today（中文輸入→生成→聆聽）、Settings（聲線／速度／提醒）、精靈 10 動作 Gallery。
- [x] 精靈分層渲染：複製 9 身體姿態 + 2 眼神 PNG 至 `assets/sprites/`，Flutter 版 `SelahSprite`（身體＋眼神覆蓋＋原生裝飾＋狀態光環），Reduce Motion 支持。
- [x] 平台配置：Android 權限（RECORD_AUDIO／INTERNET／通知）與 iOS 隱私說明（麥克風／語音辨識）已加入。
- [x] 驗證：`flutter analyze` 0 issue；11 個測試全過（DTO 契約、SQLite V3、Use Case、主題、App 啟動）；`flutter build apk --debug` 成功。
- [ ] macOS CI：新增 Flutter analyze／test／iOS 無簽名建置門禁（待授權配置 CI）。
- [ ] Supabase 真實接通：切換 `FixtureSelahApiClient` → 既有 7 個 Edge Functions（依賴有效 OpenAI secret 與授權）。
- [ ] iOS 真機與 TestFlight 驗收；Android 真機語音與音頻驗收。

- [x] 完成首批 10 个 SwiftUI Shape 原型动画及 Today／录音／Listen／Practice 触发接线。
- [x] 通过 Swift 核心测试和 iOS 模拟器 Release 构建／无签名归档；GitHub Actions run `29514198511`：259 tests，1 skipped，0 failures。
- [ ] 完成真实设备视觉、触控时序、性能和 Reduce Motion 验收。
- [ ] 静态分层精灵稳定后连续自用，再决定是否扩展剩余 P0、P1、P2 动画；本阶段不引入 Lottie、Rive 或视频资产。

## 后续吉祥物候选

- [ ] D「磨砂琥珀」：主人要求保留，供以后开发其他吉祥物时考虑。参考 `design-system/selah/mascot/seed-v4-d-frosted-amber.png`，本阶段不开发，当前主角色采用 C「短绒织物」。

## 明确排除

- 剩余 110 个宠物动画、视频运行时素材及 Rive／Lottie 动画系统；首批 10 个静态分层试点不属于排除项。
- 未经主人确认的 Supabase 外部配置变更、密钥修改、部署、合并或公开发布；本轮仅在当前分支和 CI 临时数据库执行已获授权的 migration。

## 阻塞与外部条件

- 2026-09-06：主人启动项目后，既有 Supabase 域名解析及认证入口已恢复，数据库只读精确计数通过，解除 2026-09-05 的 DNS 阻塞。尚未验证真实账户登录、AI／TTS、普通用户同步或重新下载全部远端音频。
- Web 转写函数已于 2026-09-09 部署，原 404 路由缺口已解除；四个生成／音频改善函数也已部署并完成源码核对。普通账户真实转写、真实 AI／TTS 与跨设备验收仍未完成。后台 Push 的订阅表、RLS、VAPID 与调度尚未实施，需要对应外部配置授权。
- Web 的旧 iOS 本地数据导出、iPhone Safari／实体麦克风、安装通知和正式 HTTPS 托管仍待验收。
- 当前 Windows 环境没有 Swift 与 Xcode；Swift／iOS 验证依赖 macOS CI，Deno 检查可通过临时 CLI 执行。
- TestFlight 需要 Apple Developer 账号、签名与 App Store Connect 权限。
- 后端远端迁移、认证策略变更和线上部署属于外部状态变更，执行前需主人再次确认。

## 最近验证

- 2026-09-06 Web UX reliability：本地 Web 目录静态分析无 issue；全量 Flutter 90 项测试通过；浏览器桥 Node 测试 13 项通过；正式 Web Release 构建成功。Release 包经本地 Node 静态服务器打开，桌面壳、Today 输入卡和本机学习状态可见。真实 Supabase 登录、AI／TTS／转写、跨设备同步、iPhone Safari 实体麦克风与精确多视口浏览器截图仍待外部环境验收；详见 `docs/web-ux-reliability-acceptance-2026-09-06.md`。
- 2026-09-06 C 五十姿态交付：50 张素材与五份 manifest 核验通过；`flutter analyze --no-pub` 无 issue，Flutter 79／79、Node 17／17 通过。正式 Release `bcd6314a55cb0fac`、预览 Release `c774a8589cee3d2f` 构建成功；浏览器已检查五阶段十动作、Reduce Motion、引导至 Today、原地址旧缓存更新及桌面断网重开。`5181` 的页面版本和活动 Service Worker 一致，并实证请求 S1 的十张新图；`5191` 断网后恢复精灵名、成长回忆与 S2 姿态。真实设备、弱网、线上服务与公开部署未验收；详见 `docs/web-plush-50-acceptance.md`。
- 2026-09-06 UI／UX 开发准备：DNS 解析成功；现有 publishable key 请求 `/auth/v1/settings` 返回 200，邮箱认证启用；受控本机使用既有服务端凭据执行四个 `HEAD` 精确计数，`seed_sentences` 为 30、ready 种子 `audio_manifests` 为 120、`sentences` 为 0、`learning_events` 为 1，均 HTTP 200。没有读取用户句子正文、写入云端数据或暴露凭据；未执行 AI／TTS、账户登录、Storage 全量校验或跨设备验收。详细交互设计已完成自检，待主人审阅；本轮没有产品代码改动。
- 2026-09-06 C 五阶段统一：两张新增第一／第二阶段图及三张保留图均为 1254 × 1254 RGB PNG；Windows `System.Drawing.Bitmap` 解码、PNG 签名／尺寸／色彩类型、五个唯一 SHA-256 与原件复制一致性检查通过。已目视核对单折芽、双叶、角色材质、五官与肢体；后三张和第一阶段十动作原图与已有哈希一致。记录见 `design-system/selah/mascot/prompts-c-growth-v3-early.md`，仅设计与文档，未改应用代码或运行素材。
- 2026-09-05 C 成长外形 V3：三张均为 1254 × 1254 RGB PNG，完成植物结构、五官、肢体与材质目视检查，PNG 完整性、三个不同 SHA-256 和原件复制一致性通过；第一阶段十图与已有记录的哈希全部一致。内置图像工具提示词、来源及核验见 `design-system/selah/mascot/prompts-c-growth-v3.md`。本轮只生成设计图并维护文档，未修改应用代码或运行素材，未进行应用构建，也未完成后四十种动作。
- 2026-09-05 C 视觉修订：十张第一阶段图均为 1254 × 1254 RGB PNG，五阶段对照为 1672 × 941 RGB PNG；完成全部目视、PNG 完整性、11 个不同哈希与复制一致性核对。第十张初稿拇指／弯手形已用内置图像工具修订。生成记录与原件来源见 `design-system/selah/mascot/prompts-c-stage1-v2.md`。本轮仅设计与文档，未改应用代码、未运行应用构建或声称新动画已上线。
- 2026-09-05 C 开发：`flutter analyze --no-pub` 无 issue，68 项 Flutter 测试、13 项 Node 测试通过；正式 Release `c09b325e7f7fb159`、角色预览 Release `b28d8f6ed9108ea0` 构建成功。浏览器检查真实短绒角色、十状态、五阶段、引导滚动、390 像素手机视口、1280 × 600 陪伴栏、真实 MP3 完成、减少动态效果、断网加载／播放和更新记录保留；最终浏览器 error／warn 日志为空。运行图集为 RGB，独立 alpha 导出未完成；云端服务和真机未验收。完整记录与截图索引见 `docs/web-plush-acceptance.md`。
- 2026-09-05 C 设计阶段：角色设计包三图均为 1536 × 1024 RGB PNG，完成目视、完整性及复制哈希核验。该阶段只读核对曾发现 Web 只有三类动作映射，后续 C 开发记录已取代此代码状态；重新查询既有 Supabase 域名仍返回 `DNS_ERROR_RCODE_NAME_ERROR`。
- 2026-09-05：V4 两张形象与状态板各为 1536 × 1024，页面比较图为 1774 × 887，均为 RGB PNG；完成目视、文件完整性及复制哈希核验。页面图明确标注为静态模拟，未取得当前浏览器截图、未修改或验证 Web 实时动画；记录位于 `design-system/selah/mascot/prompts-v4.md`。
- 2026-09-05：V3 四种吉祥物候选图均为 1536 × 1024 RGB PNG，每款包含主形象与两种表情；完成图片目视、完整性与复制哈希核验。A 款背景和标签对比已修订，提示词及审阅记录位于 `design-system/selah/mascot/`，未修改或验收 Web 运行动画。
- 2026-09-05：吉祥物标准图（1254 × 1254）及十状态图（1717 × 916）通过图片核验，两图均为 RGB PNG；已保留真实提示词与使用边界。本轮只改图片及对应文档，未改应用代码、未声称完成动画播放验收。
- 2026-09-05：Flutter analyze 无 issue，全部 47 项 Flutter 测试、13 项 Node 测试、163 项 Deno 测试通过；新增转写文件格式／lint／类型检查通过。最终 Release 版本为 `d068817d378f5aa0`。Edge 宽屏／手机视口验证首次引导、真实 MP3、暂停续播、切句进度隔离、复习、笔记词汇、种子加入、备份与显式更新。停止本地服务器并清空 HTTP 缓存后仍可启动、首次点击按钮、播放内置音频并保存记录，没有运行时错误；详见 `docs/web-acceptance.md`。
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
- 2026-08-03：GitHub Actions `30813697889` 成功，HEAD `e170f90`；Swift Package、iOS Build & Archive、Supabase Deno、Supabase Migration & Concurrency 全部通过。
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
