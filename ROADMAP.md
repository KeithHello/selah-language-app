# Selah 开发路线图

> 最后更新：2026-09-22
>
> 状态依据：仓库当前代码、本地自动化与浏览器验收，以及明确标记日期的历史 GitHub Actions 结果。
>
> 完成口径：遵循 `CLAUDE.md` 的五级完成定义。

## 当前阶段

### 2026-09-22 逐句听答案的母语释义点选（预览已发布，待真机验收）

- [x] 逐句听揭开答案后，拆解短语和英文正文对应片段共用同一个选中状态；点击任一入口都在英文下方就地展开母语释义，再点收起或切换句子时清空。
- [x] 拆解优先采用最长、不重叠匹配，避免 `all-nighter` 把 `pulled another all-nighter` 切碎；没有拆解时仍支持已有词汇条目点选。
- [x] 使用现有 Quiet Growth 薰衣草 token、44px 触控热区、三语无障碍标签和减少动态适配；不改句子模型、音频、循环听、练习或笔记路径。
- [x] 新增纯逻辑与正式 Web 入口 UI 回归测试；定向 Flutter 回归 61 项通过，`flutter analyze --no-pub` 无问题，`flutter build web --release` 成功生成 `SelahFlutter/build/web`。
- [x] Cloudflare Pages 预览已发布到项目 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名：部署版本 `https://287709d6.selah-language-app-preview.pages.dev`，别名 `https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`，关联 commit `b039fdb`。
- [ ] 尚未做 iPhone Safari 真机验收。

### 2026-09-22 Today 输入、分句、拆解与单句语音体验修正（预览已发布，待真机验收）

- [x] Today 输入区改为上方紧凑问候、下方大输入卡片；精灵保持 56px 主视觉，窄屏隐藏状态胶囊，输入标题、录音与生成按钮在 320px 和大字体下不溢出。
- [x] 中文／日文转写文本会按句号、问号、感叹号和换行自动分句；2—20 句直接复用批量生成合约，超过 20 句继续进入可编辑整理流程；批量结果在 Today 显示为多张独立学习卡。
- [x] 句子拆解词组改为可点击 ActionChip，点击后用底部弹层显示原词组与母语释义；词汇行同时显示英文词和对应释义，并补齐繁中、简中、日文文案。
- [x] 浏览器单句音频在用户点击时同时预解锁主音频与循环音频元素，网络／缓存完成后复用媒体权限再播放；自动播放受阻时保留可重试语义，兼容不支持音频元素的环境。
- [x] 首批 starter 音频清单收敛为当前 10 句的 60 条有效轨道，保留物理目录中的旧 MP3 但不再由清单和 Web 资源引用。
- [x] 新增句子切分与短句批量生成控制器测试；`flutter analyze`、`flutter test` 全量 284 项、Node 浏览器桥接 41 项和 `flutter build web --release` 均通过。
- [x] Cloudflare Pages 预览已发布到 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名；本轮未修改数据库、密钥、Supabase 远端函数或生产配置。

### 2026-09-22 循环听播放状态与音频复用修正（预览已发布，待真机验收）

- [x] 循环听拆分为「准备循环听」和「开始循环听」：准备阶段只增量核对、生成和缓存双语音轨，完成后显示可开始状态，不再在准备流程中启动播放或把准备完成提示带入播放页。
- [x] 播放会话把 `ready` 视为「浏览器拦截自动播放，等待用户点击」的有效会话状态；主卡片、底部迷你播放器和聆听页保持在播放上下文，用户点击「继续播放」即可恢复，不会被切回准备界面。
- [x] 浏览器桥接在用户手势内预先解锁并复用同一个 `Audio` 元素；循环切换语言和句子时只替换音频源，保留事件监听和会话，避免反复创建元素导致播放权限重新失效。
- [x] 增加准备快照指纹：句子新增、归档、文本／语言变化或声线变化会使旧准备结果失效；下一次开始只重新处理变化内容，并清理不再引用的循环听缓存。
- [x] 新增并通过控制器、UI 与 Node 桥接回归测试：准备不启动播放、ready 一键继续、单元素复用、暂停／继续、顺序切换和归档缓存清理均有覆盖。
- [x] `flutter analyze` 通过；相关 Flutter 测试全部通过；Node 循环播放测试 9 项通过；`flutter build web --release` 成功生成 `SelahFlutter/build/web`。
- [x] Cloudflare Pages 预览已发布到 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名；本轮不涉及数据库、Supabase 函数、密钥或生产环境变更。

### 2026-09-20 在线音频按语言供应商路由（已提交并发布预览）

- [x] `audio-generate` 合约升级为 v2：明确区分 `source`／`target`、原文语言／学习语言、口音与声线；保留旧版 `targetText` 请求的兼容路径。
- [x] 繁体中文母语音频固定路由到 Azure Speech 台湾普通话（`zh-TW-HsiaoChenNeural`），英文继续使用 OpenAI `tts-1`，英式声线保持 `en-GB`；日语本阶段继续使用原 OpenAI 路由。
- [x] 音频缓存键与 Storage 路径加入供应商、供应商声线、语速和文本哈希；切换供应商或声线时不会复用旧 MP3；Azure SSML 已做 XML 转义并绑定母语语速／音高配置。
- [x] 服务端加入 15 秒供应商超时、最多 2 次有限重试和明确的供应商失败记录；Azure 费用在价格核实前保持未知，不把未知费用记为 0。
- [x] Web 循环听、个人句播放和后台音频补齐统一发送 v2 元数据，并切换 `audio:v2` 本机缓存键；新增路由、重试、Azure SSML 和前端请求回归覆盖。
- [x] 本地验证：Supabase Deno 全量 320 项通过；本次 Flutter 相关测试 15 项通过；`flutter analyze` 通过；Web Release 构建成功；目标服务文件 `deno fmt --check` 通过。
- [x] 已提交并推送 GitHub：分支 `codex/web-ux-reliability`，commit `189097b`；未纳入工作区中的素材、临时目录和旧资源。
- [x] 已单独部署 `audio-generate` 到 Supabase 项目 `ijonabyyppmgvoufgamt`；远端零费用预检为 `OPTIONS 200`、未登录 `POST 401`，未修改 migration、Secrets 或其他函数。
- [x] Cloudflare Pages 预览已发布到项目 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名：部署版本 `https://32ed1a15.selah-language-app-preview.pages.dev`，别名 `https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`；首页、Flutter 主脚本、Service Worker、音频清单和代表性中文 MP3 均 HTTP 200，`main.dart.js` 已包含 `audio:v2`。

### 2026-09-20 个人句子语言 provenance 与跨端同步收尾（迁移已应用，预览已发布）

- [x] 远端只读盘点确认 `public.sentences` 现有 13 条记录；不依据旧句子文本猜测语言，所有旧记录的新增 provenance 字段保留为 `NULL`。
- [x] 新增 `008_sentence_language_provenance.sql`：为个人句子增加 `source_language`、`target_language`、`generation_model`、`prompt_version` 四个可空字段，并限制当前支持的语言代码；不改变既有 RLS 与句子内容。
- [x] 已将 008 migration 应用到 Supabase 项目 `ijonabyyppmgvoufgamt`；远端核对四列均存在且可空，13 条旧记录四列均为 `NULL`。
- [x] Web `SupabaseLearningGateway` 的读写映射已保存并恢复语言、模型与 prompt 版本；旧云端行仍可正常读取，未提供 provenance 时不会被本地同步覆盖。
- [x] 新增 migration 静态测试与句子同步映射回归测试；目标测试通过。普通账户跨设备真实登录和动态音频真实账户验收仍需后续外部验收。
- [x] 最新 Web Release 已发布到 Cloudflare Pages 项目 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名：部署版本 `https://25a9974b.selah-language-app-preview.pages.dev`，别名 `https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`；静态资源、音频清单、预缓存与代表性中文 MP3 只读验收通过。

### 2026-09-20 Azure 台湾中文母语音频重制与英语美音英音声线区分（已部署预览环境）

- [x] 首批 10 句随包种子繁体中文母语音轨（`seed-*-source-zh-Hant.mp3`）全部通过 Azure Speech（`zh-TW-HsiaoChenNeural`，区域 `japaneast`）重新生成并原子覆盖，输出规格为 16 kHz、128 kbit/s、单声道 MP3。
- [x] 本地音频清单 `seed-audio.json` 重新计算哈希与大小对齐；新增本地生成脚本 `generate_azure_seed_audio.py` 与 12 项单元测试。
- [x] 英语美音／英音声线区分：在 `learning_models.dart`、三语本地化字典（繁中、简中、日文）中为 4 种英语声线增加显式口音标注（溫柔自然（美音）、清晰慢速（美音）、日常輕快（美音）、優雅英式（英音））；设置页增加美英声线说明（`settings.voice.detail`）。
- [x] 服务端 `supabase/functions/_shared/audio.ts` 同步补充 `VOICE_ACCENTS` 映射（`en-US` / `en-GB` / `zh-TW`），为动态生成分流提供基础。
- [x] 验证：`dart analyze lib test` 0 issues；`flutter test` 全套国际化与模型测试通过；Web Release 构建成功（Build ID: `2766dd177559be71`）。
- [x] 代码已提交并推送至 GitHub（分支 `codex/web-ux-reliability`，commit `ef5c7fb`）。
- [x] Cloudflare Pages 预览环境部署完成：项目 `selah-language-app-preview`，分支别名 `https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`（部署版本：`https://c1965346.selah-language-app-preview.pages.dev`）。远端只读验收：首页 HTTP 200，中文母语代表性 MP3 HTTP 200（62,784 字节，`audio/mpeg`），音频清单 200。

### 2026-09-20 精灵 100 趣味名字池与骰子随机起名交互（已完成并验证）

- [x] 新增 100 个年轻化趣味名字池与数据模型（`SelahFlutter/lib/web/domain/companion_names.dart`），涵盖职场生存（20）、校园闯关（20）、低电量日常（20）、温柔反转（20）、食物补给（10）、荒诞彩蛋（10）六大类别；支持繁体中文、简体中文、日语三语本地化与小腹黑、小反转调性。
- [x] 首次进入 Onboarding 精灵起名步骤时，自动从 60 个低电量／温柔反转／食物／彩蛋默认池中预抽一个契合当前母语的名字，告别空白输入框与催促感，下方问候语同步响应。
- [x] 输入框右侧新增 `CompanionDiceButton` 骰子按钮组件（`SelahFlutter/lib/web/ui/companion_dice_button.dart`），提供弹性缩放与 360° 旋转骰子微动效，点击即可全池抽取新名字，自动规避连续重复；设置页面同样完整嵌入该骰子组件，方便用户后续随时重抽与保存。
- [x] 国际化三语字典（`selah_strings.dart`、`selah_zh_hant.dart`、`selah_zh_hans.dart`、`selah_ja.dart`）补齐骰子提示词；`web_l10n_test.dart`、`web_app_test.dart` 与新增的 `companion_random_names_test.dart`（100 词条唯一性、类别分布、三语非空映射、初次默认池比例、骰子动画与设置页保存联动）全部通过；`flutter analyze` 0 issues；`flutter build web --release` 构建成功。

### 2026-09-19 Today 后台双语音频预热与一键循环听（已完成并验证）

- [x] Today 单句生成与批量生成在英文内容保存完成后立即结束前台流程，同时把学习语言与母语音频按「学习语言优先、母语随后」加入后台队列；音频失败只记录待重试状态，不回滚已经保存的英文内容。
- [x] 新增稳定音频身份键 `loop:<voice>:<role>:<language>:<sha256>` 与去重队列；相同内容、角色、语言和声线复用已确认音频，声线／文本／语言变化生成新键，语速、顺序及时长变化不触发重新合成。
- [x] 循环听改为一次点击完成「解锁音频 → 增量核对 → 缓存缺失轨道 → 直接播放」；准备阶段立即展示旋转 loading 与完成数，浏览器阻止自动播放时保留 `ready` 状态并提示用户再次点击。
- [x] 归档或删除句子后，下一次循环听从清单移除对应轨道；浏览器桥按当前账户枚举 `loop:` 缓存键，仅删除不再被当前句子引用的孤立缓存，不删除服务端音频清单或普通单句播放缓存。
- [x] 新增音频身份、队列去重、Today 后台预热、一键循环听、增量复用、归档清理、自动播放受阻和界面 loading 回归测试；Node 浏览器桥与循环播放测试 29 项通过，相关 Flutter 测试通过，`flutter analyze --no-pub` 无问题。
- [x] `flutter build web --release` 成功生成 `build/web`；预览部署由发布步骤单独执行，未涉及数据库 schema／migration、密钥修改或生产部署。
- 验证边界：Flutter 全量 268 项中 266 项通过，剩余 2 项是工作区原有 starter 音频资源清单与物理文件不一致导致的既有失败，未涉及本功能。

### 2026-09-19 循环听暂停计时定格与播放页即时语速切换（已完成并验证）

- [x] 循环听暂停时间定格：底层 `selah_bridge.js` 改造，`pause()` 触发时定格记录 `pausedRemainingMs`，立即清理截止定时器 `clearDeadlineTimer()`；`snapshot()` 在 `paused` 状态下定格展示剩余时间，不再随物理时间空转倒数；`resume()` 与 `next()` 恢复播放时基于定格时间顺延重新挂载截止定时器。
- [x] 循环听播放界面嵌入语速控制：独立提取 `SpeedSelector` 组件（`SelahFlutter/lib/web/ui/speed_selector.dart`），在 `loop_listening_panel.dart` 循环听主播放卡片中加入 5 档预设（0.5x, 0.75x, 1x, 1.25x, 1.5x）及自定义语速调节；单句播放页与设置页完成统一复用。
- [x] 循环听底层动态变频广播：在 `selah_bridge.js` 的 `makeLoopAudioController` 中补齐 `speed(payload)` 方法，并将 `audioSpeed` 桥接方法广播至 `loopAudio`，支持正在播放的音频实时无缝变频且自动继承至后续句子。
- [x] 测试与构建验证：
  - `browser_loop_playback.test.mjs` 新增及更新暂停定格、超时顺延和中途调速测试，7 项测试全部通过；
  - `web_loop_listening_ui_test.dart` 与 `web_loop_controller_test.dart` 界面交互与控制器测试全部通过；
  - Web Release 构建成功，`selah_bridge.js` 产物已同步对齐。


### 2026-09-19 Azure 台湾中文母语音频第一阶段（10 条随包音频已生成并完成打包构建）

- [x] 英语美音／英音声线区分与展示开发完成：在 `learning_models.dart`、三语本地化字典（繁中、简中、日文）中为 4 种英语声线增加显式口音标注（溫柔自然（美音）、清晰慢速（美音）、日常輕快（美音）、優雅英式（英音））；设置页增加美英声线说明（`settings.voice.detail`）。
- [x] 服务端 `supabase/functions/_shared/audio.ts` 同步补充 `VOICE_ACCENTS` 映射（`en-US` / `en-GB` / `zh-TW`），与前端声线保持一致。
- [x] 验证：`dart analyze lib test` 0 issues；`flutter test` 全套国际化与模型测试通过；Web Release 构建成功（Build ID: `faef07dba28d24dd`）。
- [x] 新增本地脚本 `supabase/scripts/generate_azure_seed_audio.py`：读取现有本地 `.env`，使用 Azure Speech REST 接口与 `zh-TW-HsiaoChenNeural`，只生成十条 `seed-xxx-source-zh-Hant.mp3`，采用原子写入并拒绝无效 MP3；不会把密钥写入前端资源或输出日志。
- [x] 新增脚本单元测试，覆盖 SSML 转义、台湾声线、文件命名、缺少凭证时不发起网络请求、dry-run 和 MP3 头校验；与现有打包器测试合计 12 项通过。
- [x] 明确区域配置为 `japaneast` 后，10 条中文母语音频全部通过 Azure Speech 生成成功，输出为 16 kHz、128 kbit/s、单声道 MP3，已原子覆盖写入 `SelahFlutter/assets/audio/seed-*-source-zh-Hant.mp3`。
- [x] 已通过 `package_seed_audio.py --local` 重新计算音频清单，60 条清单（40 条英文声线、10 条中文母语、10 条日文母语）SHA-256 与文件大小全部更新对齐。
- [x] Release Web 构建成功，Build ID 为 `5a3cf40624e923ff`；本地服务 `http://127.0.0.1:5191/` 已就绪，首批 10 句随包中文母语音频已完全更新为 Azure Taiwan Mandarin 声线。
- [x] 构建包只读核对：10 句种子、60 条音频清单、10 条繁体中文母语轨道、10 条日语母语轨道、189 项预缓存；代表性 MP3 通过 HTTP 200 与 `audio/mpeg` 校验。
- [ ] 待主人试听确认 Azure 台湾中文声线在循环听中的自然度、声调与停顿效果。
- [ ] 下一阶段再把线上 `audio-generate` 拆成按源语言／供应商路由：`zh-Hant` 使用 Azure，英语继续现有 OpenAI 路由；先补合约、缓存键与失败回退测试，再单独确认 Supabase Edge Function 部署。

### 2026-09-18 测试模式匿名准入、登录 CTA、注册资料与语速完善（代码与预览发布完成）

- [x] 测试模式（`membership_enforcement_enabled=false`）在完成请求边界与费用报价校验后，匿名请求不再依赖每日平台预算账本或会员额度预留；生产模式仍保留平台预算与会员准入。新增 Node 回归测试覆盖匿名测试模式和未授权生产模式。
- [x] 生产模式触发认证限制时，当前提示条会原地显示带下划线的「请登录」链接，并复用现有登录／注册弹窗；预算、网络和一般业务错误不会误显示登录入口。
- [x] 注册弹窗新增可选年龄段、性别和「自行描述」字段，填写时必须显式同意研究用途；沿用既有 `user-research-profile` 合约，不新增数据库迁移。注册后若已取得正式会话会自动保存；若仍需邮箱确认，则提示用户登录后到设置补填。
- [x] 设置页与播放控制加入 `0.5x`、`0.75x`、`1x`、`1.25x`、`1.5x` 五档语速及自定义滑块；自定义范围为 `0.5x～2.0x`，继续使用现有本机／云端 `playback_speed` 字段，已与浏览器音频桥的实际范围对齐。
- [x] 最近本地回归：Flutter 全量 254 项通过；Dart analyze 与 `flutter analyze --no-pub` 均为 0 issues；Supabase Deno 全量 308 项通过（使用项目内固定 Deno 2.9.3）；`git diff --check` 通过；Release Web 构建成功，Build ID 为 `6278cbcd4e066101`。
- [x] 已部署 `sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`、`speech-transcribe` 五个 Supabase Edge Functions 到 `ijonabyyppmgvoufgamt`；均为 `ACTIVE`，未执行数据库迁移、密钥修改或旧种子导入。
- [x] Cloudflare Pages 预览已部署到 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名；部署地址为 `https://a2f21314.selah-language-app-preview.pages.dev`，别名地址为 `https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`，Build ID `6278cbcd4e066101`。只读验收：首页 200，`flutter_bootstrap.js`、`main.dart.js`、`flutter.js`、Service Worker 均返回 200。
- [ ] 如果生产环境继续启用邮箱确认，注册资料不会在确认前写入账户；邮件确认后的设置补填流程仍需真实远端账户验收。

### 2026-09-17 免邮箱确认与测试期游客云端功能（本地实现完成，预览站已发布；远端 Supabase 仍待启用）

- [x] 已实现测试期游客云端会话：生成英文、长文整理、批量生成、说出来转写、个人句音频补齐和循环听个人句补音频会先静默 `signInAnonymously()`。
- [x] 第一版不原地把匿名账户绑定为邮箱账户；正式注册仍走普通 `signUp`，远端关闭 Confirm email 后可立即登录。仍校验邮箱格式、密码长度和密码是否正确。
- [x] 未关闭收费 Edge Function 的 JWT。未带会话的直接 HTTP 调用仍按 401 设计；管理台继续要求管理员。
- [x] 已补强匿名测试服务端边界：新增 `anonymous_test_mode_enabled` 管理员开关、JWT `is_anonymous` 识别和独立平台预算预留／结算 RPC。匿名身份不创建会员额度；测试开关关闭时五个收费函数返回 `403 anonymous_test_ended`；缺少当天平台预算或预算超限时失败关闭，不调用 OpenAI。
- [x] 管理台新增「开放匿名测试」开关；开关默认关闭，只有管理员写权限可开启。设置页把匿名会话显示为「测试访客」，并隐藏会员中心、研究问卷与正式账户同步表述。
- [x] 已修复匿名云端入口并发竞态：多个入口同时触发时共享同一个匿名登录 Future，双击不会创建多个匿名账号。
- [x] 本地 `supabase/config.toml` 已启用 `enable_anonymous_sign_ins = true`；远端 Confirm email / Anonymous Sign-ins 未修改。
- [x] 本地 migration 文件保留 `supabase/migrations/007_anonymous_platform_budget.sql`：新增平台预算预留表、匿名测试开关列、服务控制 RPC 版本 `2026-09-17-v1` 与 service-role-only RPC；远端应用状态以紧接的验证记录为准。
- [x] 2026-09-18 远端已应用 `006`、`007` migration；`001`—`007` 全部对齐。已部署六个更新 Edge Functions，开启 Supabase Anonymous Sign-ins，并将管理台版本推进到 `2026-09-17-v1-r4`，匿名测试开关当前开启。
- [x] 2026-09-18 Cloudflare Pages 已部署 Build ID `7ac17a830f60d168`：<https://codex-web-ux-reliability.selah-language-app-preview.pages.dev>。页面 200，10 句种子，60 条音频清单，中文母语 MP3 为 `audio/mpeg`。
- [x] 2026-09-18 UTC 当日平台预算为 5 USD；热修后验证匿名开关关闭返回 `403 anonymous_test_ended`，预算为 0 返回 `403 service_budget_protected`，均不调用 OpenAI。热修前一次短 TTS 探测估算 0.0003 USD，已补记 committed；临时匿名账号已删除。
- [x] 验证：Dart analyze 0 issues；Flutter 全量 242 项通过；Deno 全量 307 项通过；Release Web 构建成功；`git diff --check` 通过。部署记录见 [匿名测试模式发布说明](docs/anonymous-test-mode-2026-09-18.md)。
- [ ] 尚未执行正式用户完整收费链路批量验收；测试结束后应通过管理开关关闭匿名测试，并按需关闭 Supabase Anonymous Sign-ins。
- [x] 已将 Build ID `ebd23fdd5327ba6d` 发布到 Cloudflare Pages 项目 `selah-language-app-preview` 的 `codex-web-ux-reliability` 预览别名：<https://codex-web-ux-reliability.selah-language-app-preview.pages.dev>。只读验收：首页 200、10 句种子、60 条音频清单、189 项预缓存和代表性 `audio/mpeg` MP3 均可访问。
- [ ] 远端 Supabase Auth、SMTP 或真实 OpenAI 尚未启用／验收；旧 20 句远端种子继续不处理。详见 [本地验收记录](docs/guest-cloud-access-acceptance.md)。

### 2026-09-18 Web 二元运行模式与首次引导（本地实现完成；Cloudflare 预览已部署）

- [x] 管理台服务控制收敛为单一「运行模式」：测试模式同时开启匿名测试、关闭会员限制并保持新增生成；生产模式关闭匿名测试、开启会员限制并保持新增生成。混合或不完整配置按生产安全回退。
- [x] 匿名会话继续使用本机 `guest` 资料作用域，不再在建立匿名 Supabase 身份时切换页面、清空状态或启动跨设备同步；正式账户才切换账户作用域并同步。
- [x] 已修复已有匿名会话刷新后的启动路径：初始化始终把匿名身份映射回 `guest` 作用域，本机资料可正常恢复，不会停留在加载态。
- [x] 生成、转写、音频补齐、循环听和草稿重试都可在测试模式静默建立匿名会话；匿名资料导入入口改为原地提示，正式账户才执行本机资料合并。
- [x] 错误提示保存 `LearningFailure.code`；只有真正的认证限制才显示登录／注册按钮，预算、网络、音频和普通业务错误保持当前页面原地提示。
- [x] 已统一清理试听、轮询、账户加载和本机资料读取路径的旧错误码，避免普通音频错误沿用登录提示。
- [x] 混合或不完整的远端服务开关会显示风险提示，并提供直接应用生产模式的归一化操作，避免管理员必须先切换到测试模式才能关闭匿名入口。
- [x] 首次引导把精灵名字改为高对比步骤卡：明确「第 1 步」、必填标识、说明、放大输入框、实时问候预览；点击开始会聚焦缺失字段并显示名称／句子数量错误，不再静默禁用。
- [x] 测试覆盖运行模式合约、匿名本机作用域、刷新恢复、草稿重试、错误 CTA、错误码清理、混合配置归一化、管理台模式控件和三语名称引导；`flutter test` 全量 251 项通过，相关 Dart analyze 0 issues。
- [x] `tool/web.ps1 -Action build` Release 构建成功，Build ID 为 `c19efc446a159867`；未修改 Supabase、数据库、密钥或正式生产域名配置。
- [x] Cloudflare Pages 预览已部署到项目 `selah-language-app-preview` 的 `codex-web-ux-reliability` 别名：<https://codex-web-ux-reliability.selah-language-app-preview.pages.dev>。远端只读验收：首页 200、Build ID 一致、10 句种子、60 条音频清单、189 项预缓存和代表性中文 MP3 的 `audio/mpeg` 均通过。
- [ ] 仍需在后续单独验证真实管理账号切换测试／生产模式，以及生产模式下匿名请求收到 `anonymous_test_ended` 后的实际登录流程；这两项不在本地代码测试中完成。

### 2026-09-16 未登录快捷登录、注册邮件排查、母语配音与首批 10 句收口（本地实现完成；邮件发送仍待远端配置）

- [x] 未登录提示条在需要登录时提供登录按钮，直接打开现有登录／注册弹窗；相关 Widget 测试通过。
- [x] 注册与找回密码通过 `selahAuthRedirectUrl()` 传站点根地址给 Supabase Auth，自动移除 query、hash 和 Flutter 应用路由，同时保留 scheme、host、port 与部署子路径，避免 Supabase Auth fragment 与应用路由冲突。
- [x] 远端 Auth 只读核对：mailer_autoconfirm=false，SMTP 未配置，site_url=http://localhost:3000，uri_allow_list 为空。因此注册确认邮件目前发不出去，不是前端注册接口本身报错。
- [x] 循环听个人句子的母语轨道改为独立 nativeVoice；设置页新增母语声线选择，默认语速改为 1.0。TTS 合约同步支持 native-* 声线，合成速度改为 1。
- [x] 首批 starter 正式收口为 10 句，顺序为 `seed-001`、`seed-006`、`seed-027`、`seed-012`、`seed-016`、`seed-021`、`seed-004`、`seed-010`、`seed-030`、`seed-020`；剩余 20 句不在种子 JSON、界面、音频 manifest、预缓存清单或 Release 包中显示。
- [x] 每句保留 4 个英文声线、1 条繁体中文母语音轨和 1 条日语母语音轨；正式 Web 包共 60 个 MP3。`pubspec.yaml` 改为显式声明这 60 个文件，不再整目录打包 `assets/audio/`，旧 20 句的 80 个历史英文 MP3 只保留在源码目录，不进入 Release 包。
- [x] Service Worker 的种子音频路径规则支持 `source-zh-Hant.mp3` 的大小写混合，离线预缓存清单与测试夹具均按 10 句、60 音轨核对。
- [x] 最近验证：Dart analyze 0 issues；Flutter 全量 239 项通过；Node 浏览器桥、循环播放、Service Worker、资源与构建配置测试 35 项通过；Deno 音频合约和声线映射测试 46 项通过；Deno fmt 检查通过。
- [x] 标准 Release 构建成功，Build ID 为 `48701eec5933e652`。构建目录核对结果：种子 JSON 为 10 句，音频 manifest 为 60 条，物理 MP3 为 60 个，`selah-precache.json` 共 189 个资源且其中 60 个为音频，旧 20 句音频和文本引用均为 0。
- [ ] 注册邮件真正发出仍需单独确认：配置 SMTP 或关闭邮件确认，并把 site_url／允许回跳地址改成本地 Web 预览或正式 HTTPS 地址。
- [x] 2026-09-16 已单独部署 audio-generate 到 ijonabyyppmgvoufgamt，未跑整包部署、未改 secret/migration。零费用检查为 OPTIONS 200、未登录 POST 401。远端函数包含 native-gentle/alloy、native-clear/echo、native-bright/onyx、native-calm/fable，TTS_SPEED=1。

### 2026-09-16 Web 循环听游客闭环、自定义时长与三句引导（本地实现完成）

- [x] 初始引导从至少选择 5 句改为至少 3 句，默认推荐 `seed-001`、`seed-006`、`seed-012`；名称、按钮禁用条件、三语文案与控制器校验同步更新。
- [x] 循环听不再要求登录：游客可直接使用随包种子的英文与母语音频循环播放；个人句子缺少云端音频时明确提示登录补齐，不发起匿名云端请求。
- [x] 点击「自定义」始终允许自由输入 1～720 分钟整数，回填当前时长，保存成功后关闭；非法输入保留弹窗并显示三语校验文案。
- [x] 循环听拆分为「准备循环听」和「开始循环听」两步，先校验／缓存双语轨道，再由用户显式开始；声音、句子或偏好变化后会要求重新准备。
- [x] 浏览器循环内核使用绝对截止定时器，暂停期间继续占用总时长且无需轮询即可到点结束；暂停中切换顺序从下一语言阶段或下一句生效，避免打断当前播放。
- [x] `audio-download-url` 改为 POST 调用；音频下载地址允许远端 HTTPS 与本机 `localhost`／`127.0.0.1`，已知浏览器音频错误显示具体原因。
- [x] 最近验证：Flutter 全量 229 项通过；Node 浏览器桥与资源测试 35 项通过；标准 `tool/web.ps1 -Action build` Release 构建成功并确认编入公开 Supabase 配置。`flutter analyze` 被本机 Flutter SDK 内损坏的 `dev/benchmarks/macrobenchmarks/macos/Runner` 目录阻断，新增代码已用 `dart analyze` 检查通过。未部署远端、未修改数据库、密钥或支付配置。
- [x] 2026-09-16 已创建 Cloudflare Pages 预览项目 `selah-language-app-preview`，并将 Build ID `bac2831a0c01e394` 的 301 个静态文件部署到分支别名 `codex-web-ux-reliability`。预览地址：`https://codex-web-ux-reliability.selah-language-app-preview.pages.dev`。首页、`selah_bridge.js`、`selah-precache.json`、`main.dart.js`、母语音频和 GIF 均为 HTTP 200；Content-Type 分别为 HTML、JavaScript、JSON、JavaScript、`audio/mpeg`、`image/gif`。真实浏览器确认页面加载完成、`flutter-view` 已挂载、加载层隐藏，控制台错误／警告为 0。未绑定自定义域名、未改 DNS、未部署 Edge Functions、未执行数据库 migration 或支付配置变更。


### 2026-09-15 十句 starter 双语种子与本地母语音频（本地完成；远端未导入）

- [x] 首批种子已从 30 句收敛为 10 句，固定顺序为 `seed-001`、`seed-006`、`seed-027`、`seed-012`、`seed-016`、`seed-021`、`seed-004`、`seed-010`、`seed-030`、`seed-020`；覆盖工作、朋友、生活日常、吐槽、心里话和想法六类。
- [x] `SeedContent/seed-sentences.json` 与 Web 资源清单保持一致；每句都有 `zh_text`、`ja_text`、`en_translation`，并标注 `sourceLanguage: zh-Hant`、`targetLanguage: en`。
- [x] 本地音频清单为 60 条：10 句 × 4 种英文声线，加 10 条中文母语和 10 条日文母语 MP3；每条文件的 SHA-256、字节数和 MP3 头均已核对。
- [x] 循环听种子接线支持 `seed-xxx:source:zh-Hant` 与 `seed-xxx:source:ja`；日语母语偏好会显示对应 `ja_text`，不会静默回退为中文；内置 URL 已匹配 Flutter Web 的 `assets/assets/audio/...` 资源入口。
- [x] 回归证据：种子／循环音轨 Flutter 测试 5 项通过；相关 `dart analyze` 无 issue；打包器 Python 测试 6 项通过；本地 Web Release 构建 Build ID 为 `3c5e4fd11eb124c6`，HTTP 资源核对为 10 句、60 条清单、20 个母语文件。
- [ ] 本轮未执行远端 Supabase seed 导入、schema／migration、真实账户同步或 Cloudflare Pages；远端仍需单独确认后才能视为同步完成。
- [ ] `SelahFlutter/assets/audio/` 中未被当前清单引用的旧英文 MP3 暂不删除；循环听修正规划中的自定义时长、准备／开始分离、暂停改序和独立截止也未包含在本轮。


### 2026-09-15 循环听完整修正最终开发方案（仅文档，未改产品代码）

- [x] 已重新衡量 2026-09-11 方案与当前代码：嵌套 `_run()` 启动拦截已不再是主缺陷；仍未修好自定义时长、准备／开始混在一起、循环听 `GET` 刷新音频、暂停改序重复语言、播放中无独立截止计时器。
- [x] 最终实施入口为 [循环听完整修正计划](docs/superpowers/plans/2026-09-15-loop-listening-fix-plan.md) 。旧稿 [2026-09-10 循环听整体开发计划](docs/superpowers/plans/2026-09-10-loop-listening-plan.md) 只作历史参考，不再按从零重建执行。
- [x] 本轮范围是 T1 自定义四选一、T2 先准备再开始、T3 POST 下载与明确错误、T4 下一句改序与独立截止、T5 种子母语库存核对、T6 本地回归。付费母语预制、真实账户 AI／TTS、锁屏 60 分钟和 Cloudflare Pages 仍需单独确认。
- [ ] 尚未授权改产品代码、测试实现、本地重建或公开部署；文档存在不代表循环听已可上线。

### 2026-09-15 50 个吉祥物固定轮廓 GIF 重制与网站资源替换（已完成）

- [x] 主人确认 5 个取景样品方向后，已将全部 50 个吉祥物动作改为「固定各自主姿态＋整只角色小幅刚体运动」，不再在不同动作姿态之间硬切。
- [x] 新增可复用脚本 `skills/mascot-to-gif/scripts/build_fixed_pose_gifs.py`，从 `SelahFlutter/assets/sprites_backup_png/` 的 RGBA 母版生成 800 张透明帧和 50 个 768×768、16 帧、`loop=0` 的 GIF。
- [x] 输出目录为 `output/mascot-gif-fixed-pose-20260915-v1/`，包含独立 GIF、逐帧 PNG、五阶段联系表、验收清单与旧运行资源留档；未修改 RGBA 备份母版。
- [x] 已将同一 GIF 字节同时写入源码资源和当前本地构建资源的 `.png`／`.gif` 路径：`SelahFlutter/assets/sprites/` 与 `SelahFlutter/build/web/assets/assets/sprites/`。Flutter 继续按原 `.png` 资源路径请求，解码器按 GIF 文件头播放动图。
- [x] 已将源码入口和当前本地构建的 Build ID／Service Worker 缓存版本更新为 `2026-09-15-fixed-pose-gifs-v1`，避免浏览器继续使用旧缓存。
- [x] 最近验证：Pillow 独立解码源码资源和当前 `build/web` 各 50 个正式 `.png` 路径，全部为 16 帧、无限循环，最小边距 124 px，宽度跳动最大 10 px、高度跳动最大 8 px；`.png` 与同名 `.gif` 字节一致。
- [x] 自动验证：`node --test SelahFlutter/test/plush_assets.test.mjs SelahFlutter/test/service_worker_poses.test.mjs` 共 8 项通过；`dart analyze lib test` 0 issues；`git diff --check` 通过。
- [x] 本地静态服务 `http://127.0.0.1:8795/?v=2026-09-15-fixed-pose-gifs-v1` 已核对代表资源 HTTP 200，返回字节与当前 `build/web` 文件一致，文件头为 `GIF89a`。
- [ ] 未执行公开发布或远端部署；`flutter analyze` 因本机 Flutter SDK 的 `D:\setup\flutter\dev\benchmarks\macrobenchmarks\macros\Runner` 目录损坏而崩溃，已用 `dart analyze lib test` 替代验证。

### 2026-09-15 本地云端登录、免费 AI 服务与用户界面收口（本地实现完成；管理函数远端待部署）

- [x] Web release 标准构建会读取根 `.env` 中既有的 `SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY`，构建后检查二者确实编入 `build/web/main.dart.js`；缺公开配置时明确警告为只能本机学习，不再静默产出看似可登录的包。
- [x] 设定页恢复已配置构建的「登录／注册」；未配置时才显示云端未连接。登录与会员方案解耦，免费模式下已登录用户仍可进入现有云端 AI 函数。
- [x] 用户设定不再显示管理台卡片或「打开管理台」；管理台仅保留同源 `/#/admin`，未登录显示登录入口，普通账号仍由服务端管理员校验拒绝。
- [x] 会员限制关闭时，用户端不显示「会员与方案」整卡，也不显示「公开体验模式」；五个收费 AI 入口继续统一传入 `membershipEnforcementEnabled=false`，跳过会员／试用额度 RPC，但保留登录、请求大小、频率与紧急停机保护。
- [x] 右侧陪伴栏新增本机偏好，默认隐藏；设定「陪伴」可打开，栏上可收起。该偏好不进入云端用户资料，云同步不会覆盖。
- [x] 最近验证：Flutter 全量 220 项通过；相关 Dart 文件 `dart analyze` 0 issues；Node 合约／浏览器桥接 51 项通过；标准 `web.ps1 -Action build` 成功并输出 `Selah Web: bundled public Supabase cloud config.`；产物检索确认 Supabase URL 与公开 key 均在 `main.dart.js`，Build ID 为 `92a45c19f46ff00e`。
- [x] 无凭证远端预检确认 `speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate` 均为 `OPTIONS 200`；未提交真实内容，未触发 AI 费用。
- [x] `membership-status` 与 `admin-service-controls` 已在 2026-09-15 部署为 ACTIVE，`verify_jwt=true`；无凭证路由检查从 `404` 变为 `OPTIONS 200`、`GET 401 UNAUTHORIZED_NO_AUTH_HEADER`。
- [ ] 平台开关与会员摘要 schema 尚未应用：管理台读取默认免费状态可容错，但开关保存依赖 006 migration 的 `is_admin_operator`、`get_platform_service_controls` 与 `set_platform_service_controls`；需独立授权后再执行 migration，并确认当前管理员在 `admin_members`／`admin_operators` 中。

### 2026-09-15 Web 管理员用量与费用 Dashboard（本地实现完成；远端 schema／部署待授权）

- [x] 完成管理员 Dashboard 数据合约：活跃学习人数、学习会话、30 秒活动心跳去重后的有效学习时长、功能使用次数、业务请求数、缓存重放数、实际供应商调用数、未知用量和估算费用。
- [x] 新增本地 migration `005_admin_usage_dashboard.sql`：管理员 allowlist、业务事件、供应商 attempt、OpenAI 每日费用快照，以及仅 service role／管理员可调用的汇总和明细 RPC；普通浏览器角色无权直接读写统计表。
- [x] 五类收费链路均已接入供应商 attempt：转写、单句生成、长文本整理、批量生成和 TTS；重放不产生供应商 attempt，一批最多五句只记录一次调用，Storage 重试不重复计算 TTS，供应商成功但交付失败会分开记录。
- [x] 新增 `admin-summary` 与 `admin-cost-sync` 两个 Edge Function；后者只在服务端使用 OpenAI Admin Key，支持管理员手动同步每日项目费用，浏览器不接触管理密钥。
- [x] Web 端已接入 30 秒隐私安全心跳、设置页管理台入口、无权限状态、UTC 时间范围筛选、学习与费用概览、费用分布、功能使用和最近 API 调用；统计字段只含数字、枚举、时间和请求 ID，不保存原句、录音或供应商响应正文。
- [x] 修复 `admin-cost-sync` 写库字段：删除 `005` 统计表不存在的 `raw_line_item_key`，避免 OpenAI Costs API 成功但快照入库失败；新增回归断言约束 upsert payload。
- [x] 最近验证：Deno 全套 293 项通过，Flutter Web 全量 220 项通过，浏览器桥接、Service Worker 与 Web 资源 Node 测试 33 项通过，两个管理函数 `deno check` 与 Deno fmt 通过，管理台 Dart analyze 0 issues，标准 Web Release 构建成功并确认编入公开 Supabase 配置；实施记录见 [管理员用量与费用统计](docs/admin-usage-dashboard-2026-09-15.md)。
- [x] OpenAI 本地配置复验成功：`OPENAI_API_KEY` 调用 `/v1/models` 返回 200，`OPENAI_ADMIN_API_KEY` 调用 `/v1/organization/costs` 返回 200，`OPENAI_PROJECT_ID` 被费用查询接受。
- [x] 2026-09-15 已在远端只应用并登记 `005_admin_usage_dashboard.sql`：四张统计表和三个 RPC 存在且 RLS 已启用；已确认 `006_membership_cost_control.sql` 未应用，会员、试用、支付和服务开关 schema 没有随统计功能误上线。
- [x] 已创建专用后台管理员 `98f391e3-3543-4757-8cf7-8279a89e597e` 并加入 `admin_members`；随机密码仅保存在本机 Temp 凭据文件，不进入仓库、`.env` 或聊天记录。
- [x] 已在 Supabase Edge Secrets 配置 `OPENAI_API_KEY`、`OPENAI_ADMIN_API_KEY`、`OPENAI_PROJECT_ID`；Supabase 平台内置 `SUPABASE_URL` 与 `SUPABASE_SERVICE_ROLE_KEY` 保持由平台提供。
- [x] 已部署 `admin-summary` 与 `admin-cost-sync`，并重新部署 `speech-transcribe`、`sentences-generate`、`sentences-prepare`、`sentences-batch-generate`、`audio-generate`；七个函数均为 `OPTIONS 200`、未登录 `POST 401`。
- [x] 修复 OpenAI Costs 查询参数：官方接口要求 `start_time`／`end_time`；已新增回归测试并重新部署 `admin-cost-sync`。管理员连续两次调用费用同步均返回 `200`，最近 7 天无 OpenAI 金额记录，`upserted=0`。
- [x] 管理员调用 `admin-summary` 返回 `200`，响应包含 `summary`、`attempts`、`view`、`generatedAt`；当前尚无真实收费链路数据。
- [ ] 尚未执行普通账号真实收费端到端验收：转写、单句生成、长文整理、批量生成、TTS、重放、MP3 下载、attempt 记录和 Dashboard 数据核对。

### 2026-09-13 自适应反馈问卷与付费引导（应用层完成；真实支付与数据库待确认）

- [x] 完成问卷策略设计：按首次核心闭环、多活跃日、低使用续访、试用受限、会员临期五类时机触发，区分即时微反馈、主问卷、阻碍诊断、NPS／续购反馈，不把注册时间作为唯一触发条件。
- [x] 完成独立交互 Demo：覆盖刚激活、高频试用、低使用续访、试用受限、会员续期五个场景；问卷会根据真实行为桶和当前回答动态跳过、追问或进入不同方案解释路径。
- [x] Demo 明确商业边界：问卷不影响试用或会员权益、不展示剩余额度、不强制开放题、不直接发起付款；高意向用户仅进入既有 39.9 元月会员完整方案说明。
- [x] 设计后续汇总口径：记录触发上下文、行为桶、题目版本、选项、分支路径、研究同意、方案页打开和后续转化；不记录原始句子、录音、音频或支付凭据。
- [x] 最近验证：`node --check docs/superpowers/specs/2026-09-13-adaptive-feedback-survey-demo.js` 通过。独立原型已保留，正式应用接入另有独立验收。
- [x] 2026-09-13 正式 Web 已接入自适应问卷：首次个人表达后至少 48 小时且有两个学习日才出现主分支；低频回访用户在第 5 天进入轻量分支；展示冷却 30 天，提交后冷却 90 天；同一会话不会与画像邀请叠加。
- [x] 问卷已支持繁体中文、简体中文和日语母语显示；题目分支只依赖稳定选项 ID，不依赖翻译文本；事件只保存版本、阶段、语言、评分和选项 ID，不保存原句、录音或开放文本。
- [x] 问卷反馈事件已接入 `learning_events`，并通过客户端事件 ID与服务端插入幂等处理，后续可按场景、满意度、阻碍、付费意向和方案偏好聚合分析。
- [x] 会员中心已加入三层展示：免费／个人试用、Plus（39.9 元／月）和 Pro（99.9 元／月，高频生成、配音和转写）；Pro 已建立客户端与服务端版本化合约，但默认显示「即将开放」，不会误发起未配置的付款。Plus 与 Pro 购买入口还同时受 `paymentProviderConfigured` 保护，未配置真实渠道时显示「支付渠道待接入」。
- [x] 最近验证：Flutter 全量测试 214 项通过，Dart analyzer 0 issues，Web Release 构建成功；问卷、Pro 解析、会员三栏窄屏布局、三语邀请和支付渠道保护均有专项覆盖。Supabase Deno 合约测试因本机未安装 `deno` 暂未执行。
- [ ] Pro 尚未实际收费：当前数据库约束、订单创建、付款核验仍只支持 Plus SKU；尚未选择支付宝、微信支付或 Stripe 等真实渠道，也未配置商户密钥、回调、退款和查单。
- [ ] 数据库 migration、真实支付适配器、密钥与远端部署仍需主人明确授权和支付渠道确认；`membership-checkout` 也会在 provider adapter 未就绪时拒绝创建订单，本地 Pro 卡片与订单骨架不代表已能收款。
- 产物：[交互 Demo](docs/superpowers/specs/2026-09-13-adaptive-feedback-survey-demo.html) 、[Demo 逻辑](docs/superpowers/specs/2026-09-13-adaptive-feedback-survey-demo.js) 。

### 2026-09-13 注册画像与试用权限开发（应用层完成，数据库迁移待授权）

- [x] 画像合约与 `user-research-profile` Edge Function 已加入：字段白名单、稳定枚举、Unicode 长度限制、明确告知版本、保存同意、跳过、撤回、修订冲突和未满 14 岁策略门槛；客户端设置页与首次有效学习后的轻量邀请已接入。
- [x] 试用状态模型已加入 `not_started`、`preparing`、`active`、`expired`、`unavailable`；会员中心会区分准备中、未开始、已过期和读取不可用，不显示伪造剩余额度。
- [x] 单句与批量英文生成已切换到共同 `complete_personal_generation` 原子完成入口；成功结果、表达计量与首次试用起算由同一数据库事务负责，完成失败不会向客户端返回成功。
- [x] 管理台已加入按单一画像维度加载聚合摘要的应用契约、权限保护入口、样本不足显示与注册／覆盖／未填写／不愿透露／撤回口径；不展示个人问卷明细。
- [x] 所有语音生成、转写、整理和句子生成入口继续要求已验证登录；新增 Node 合约测试 40 项全通过，画像／试用／准入／认证测试覆盖关键边界；Flutter 画像、会员、后台和主学习页回归测试 17 项通过，主 Web 回归 82 项通过，相关 Dart 分析无问题。
- [x] 2026-09-13 修正研究资料校验结果的 TypeScript 联合类型，更新句子生成静态断言以检查共享原子完成模块，并为明确免费模式补上缺失新 RPC 时的旧完成入口回退；Deno 全套服务端合约测试 286 项通过、0 失败。
- [x] 2026-09-13 补充[当前验收记录](docs/registration-profile-trial-acceptance.md)，将应用层证据与数据库／支付／政策／部署门槛分开记录。
- [ ] 数据库 migration 尚未创建：需要新增预备试用状态、唯一试用记录、原子预占／完成 RPC、画像表与 RLS、后台聚合 RPC，并在隔离环境完成并发与撤回测试；按全局红线，创建或应用 migration 前需主人明确授权。
- [ ] 启用条件：目标地区、年龄与儿童路径、研究告知／保存期限及备份处置、隔离数据库验证、真实账户与付费样本、配置、部署和公开发布仍单独确认。

### 2026-09-12 50 个吉祥物动图生效修复与应用资源同步（已完成）

- [x] 主人已认可 `8777` 的 Stage 1 A01—A03 表现形式；已核对正式 50 张运行 PNG 和动作编号，本轮设计范围为其余 47 项。
- [x] 完成每项动作的短剧情、同阶段来源姿态、16 帧节奏与运动参数、衔接风险及后续制作验收要求；Stage 1 为 7 项，Stage 2—5 各 10 项，共 47 项、752 条逐帧记录。
- [x] 整理 `docs/superpowers/specs/2026-09-11-mascot-47-action-design.md` 及同名 JSON、`docs/superpowers/plans/2026-09-11-mascot-47-gif-production-plan.md`，独立总览位于 `output/mascot-gif-47-design-20260911/preview.html`，本地入口为 `http://127.0.0.1:8778/preview.html`。
- 最近验证：47 项编号完整唯一，所有帧引用同阶段来源、主姿态至少 11 帧、首尾来源及变换完全一致；50 张原始 PNG 与预览副本、三个已认可 GIF 与参考副本的 SHA-256 一致。设计 JSON 和计划副本一致，47 项文字说明及 HTML 下载链接有效，预览脚本语法检查通过。本轮新 GIF 为 0，应用资源未替换。
- 浏览器验证：总览已加载并检查桌面布局；Stage 5 显示 10 项，编号搜索定位 S5-A09，棋盘格切换与背景选中状态正常，展开表格含完整 16 帧。后续跨阶段组合筛选、窄屏及最终标签页展示检查被自动审批的工具额度限制中断，未列为通过。
- [x] 主人明确授权按设计方案完整开发 50 个动作并生成独立 HTML 预览页。
- [x] 完成 5 阶段 50 张正式原图的阴影剔除预检、同阶段尺度归一化与统一调色板生成。
- [x] 成功批量生成其余 47 个动作的 16 帧循环透明 GIF（768×768、disposal=2、loop=0、留白≥100px、无形变拉伸），连同已认可的 3 个 Stage 1 样本完整构成 50 个动作资产。
- [x] 生成对应 47 张 3072×3072 的 4×4 图集及 752 张透明 RGBA 关键帧母版，输出至 `output/mascot-gif-47-production-20260911-v1/`。
- [x] 搭建全量独立审阅预览服务：`http://127.0.0.1:8780/preview.html`，支持 5 阶段切换、业务用途筛选、棋盘格/白底/深灰底即时对比、一键暂停播放与图集外链。本轮未替换应用内正式素材。
- [x] 主人确认效果良好并指示替换网站吉祥物图片。
- [x] 已备份 50 张原版静态 PNG 至 `SelahFlutter/assets/sprites_backup_png/`。
- [x] 排查发现 Flutter Web 编译包通过二进制 `AssetManifest.bin` 寻址，且浏览器 Service Worker 强缓存了旧版静态资源。
- [x] 将全部 50 个 16 帧循环透明 GIF 直接注入项目与编译产物路径，使 Flutter 资源系统透明加载动图。
- [x] 更新 `index.html` 中的 `selah-build-id` 及 Service Worker 版本号（触发浏览器跳过旧缓存刷新最新动图）。
- [x] 验证 `PlushV4S1A01.png` 至 `PlushV4S5A10.png` 真实文件头已全部更新为 `GIF89a`，测试用例 `service_worker_poses.test.mjs` 6/6 通过，Dart 静态分析 0 报错。
- [x] 单元测试 `node test/service_worker_poses.test.mjs`（6/6通过）与 `dart analyze`（0 issue）验证通过。

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
### 2026-09-10 会员、试用与费用保护（本地代码与验证完成；数据库／支付接线待确认）

- [x] 完成 [会员／试用／费用保护设计](docs/superpowers/specs/2026-09-10-membership-cost-control-design.md) 、[独立交互展示稿](docs/superpowers/specs/2026-09-10-membership-cost-control-ui.html) 和 [分阶段开发计划](docs/superpowers/plans/2026-09-10-membership-cost-control-plan.md) 。产品方向为免费示例、7 天限额试用、39.9 元月会员；购买前展示完整静态权益，日常不展示剩余额度。
- [x] 2026-09-11 完成交付核对，补齐 [方案总结与八张界面图片索引](docs/superpowers/specs/2026-09-11-membership-delivery.md) 及会员开通成功截图；前七张历史图片补充正确 JPEG 后缀副本，画面字节一致，原链接保留。
- [x] 2026-09-11 追加 [Dashboard 会员运营方案](docs/superpowers/specs/2026-09-11-membership-dashboard-design.md) ：已核对现有学习／费用看板代码和本地访问路径；补齐已购补发、人工核实收款、整月赠送／补偿、撤销误赠、用户／订单／用量／异常／审计管理，开发并入 T08a—T08e，新增 D01—D12 验收定义。
- [x] 2026-09-11 完成 [最终完整开发方案](docs/superpowers/plans/2026-09-11-membership-dashboard-final-plan.md) ，统一商业规则、用户端与后台、费用保护、工具／接口准备、待确认项、T00—T10 和 A／D／G 验收；本文已补充实际实施状态。
- [x] 2026-09-12 完成共享服务控制快照与管理员开关接口：会员模式、试用入口、会员销售和生成服务四个开关均由服务端读取；数据库设置缺失时回退到安全免费模式，管理员写操作安全失败。
- [x] 2026-09-12 完成四条生成／整理／转写／配音入口的统一开关和准入接线；请求边界、会员权益、预算预占和结构化限制错误均在供应商调用前检查，生成入口不再把旧日额度当作会员上限。
- [x] 2026-09-12 完成用户端会员中心、订单查询恢复、静态权益卡片、GPT／AI 合成说明和设置入口；界面不显示剩余／已用数字，会员模式关闭时继续走免费学习路径。
- [x] 2026-09-12 完成同源 `/#/admin` 入口、Dashboard 服务控制卡、脱敏用户搜索／游标分页、用户详情和受控会员操作面板；服务端仍强制管理员与操作员权限，不能由前端直接切换会员布尔值。
- [x] 2026-09-12—13 本地验证：完整 Supabase 合约测试 286 项通过；此前完整 Flutter 测试 194 项通过；`dart analyze lib/web` 无问题；`flutter build web --release` 成功。
- [x] 2026-09-12 修正既有句子输出合约测试遗漏的 `validateSentenceGenerationInput` 导入，并同步转写测试对服务控制 RPC 的断言，完整后端测试恢复全绿。
- Dashboard 当前访问方式：运行 Web 应用后打开同源 `/#/admin`（现有本地服务端口按启动命令确定，例如 `http://127.0.0.1:5191/#/admin`）；设置页也提供管理台入口。该路径只负责导航，权限仍由服务端校验。
- [x] 2026-09-12 补齐 `006_membership_cost_control.sql` 本地草稿：平台服务开关、管理员操作员权限、试用激活、月末账期、平台日预算预占／结算、管理员会员原子动作、幂等审计、并发锁、退款／请求冲突校验和敏感表权限均已写入；新增 Migration 合约测试 7 项通过；客户端已正确区分 `system_trial` 试用来源。
- [x] 2026-09-12 收紧支付回调边界：回调信封校验金额／币种／事件／时间窗，使用固定 canonical payload 的 HMAC-SHA256；未配置渠道签名密钥时公开回调默认返回不可用，退款回调在专用核销逻辑接通前不改变订单或会员。
- [x] 2026-09-12 收紧后台订单重放：只能复用订单已有或管理员提供的真实渠道交易号，缺失交易号时拒绝，不再接受占位交易号完成付款核验。
- [x] 2026-09-12 修复循环听回归：访客账户按 `guest` 正确校验，目标／母语音轨缓存键包含角色与语言，父级重建后活动循环仍保持播放界面；Flutter 全量回归 194 项通过。
- [ ] 数据库仍未应用：尚需在获准的隔离数据库执行事务／并发回归；未配置 migration 时服务端继续安全回退，不能把本地草稿当作已启用。
- [ ] 本轮未能运行 Supabase 本地数据库 lint：Docker daemon 不可用，环境中的 `npx supabase` 也无法从 registry 启动；需在可用的隔离数据库中完成 SQL 解析、迁移和事务验证。
- [ ] 真实支付渠道、签名核验、退款／查单、资源下载预算、供应商账单对账、真机浏览器验收和远端部署仍待对应确认；本地 mock、源码存在和 release 构建不代表平台已启用。
- [ ] 上线门槛：转写费用上界、完整权益可履约、支付渠道、试用 2 元／会员每账期 20 元模型预算、存储／流量与基础设施预算待确认。2 元／20 元不是已保证的最高总账单。

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

### 2026-09-12 循环听例句母语音频包适配

- [x] 已按“例句使用预制母语音频”的方案调整本地准备链路：循环听 source 音轨支持读取 `seed-xxx:source` 形式的本地清单；target 音轨继续复用 `seed-xxx:<voice>`。
- [x] 已扩展 `SelahFlutter/tool/package_seed_audio.py --local`，可识别并校验 `assets/audio/seed-xxx-source.mp3`，将其写入 `seed-audio.json`；脚本只校验本地既有 MP3，不调用 TTS。
- [x] 已补充离线双语音轨控制器测试与静态验证：Dart 分析新增循环相关文件无 issue；浏览器循环播放 Node 测试 4 项通过。
- [ ] 30 个实际中文母语 MP3 文件尚不存在，需放入 `SelahFlutter/assets/audio/seed-001-source.mp3` ～ `seed-030-source.mp3` 后运行本地打包脚本，再执行 Web Release 构建和真机锁屏验收。
- [ ] 当前环境 Python 被 `uv trampoline ... permission denied` 阻断，未实际改写 `seed-audio.json`；不得把英文音频当作中文母语音频。
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
