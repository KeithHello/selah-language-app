# Selah 界面语言实施计划

> 原始实施分解文档。核心代码已按本计划执行；原有复选框保留用于追溯，实际状态以本文件「执行记录」与 `ROADMAP.md` 为准。本计划不触发自动实施、agent 分派、付费调用或部署。2026-09-10 的“合并实施补充”覆盖旧版把 `uiLocale` 与 `nativeLanguage` 分开设置的描述。

**目标：** 正式 Web 只提供一个“母语”选择：繁體中文／简体中文／日本語，默认 `zh-Hant`。该选择同时决定界面文案和之后输入语境，按本机账户保存并优先恢复。学习语言区显示英语与日本語两个选项，英语当前可用，日本語灰色禁用并标注「之後準備加入」，实际目标语言仍为英语；选择不改已有句子。

**架构：** 纯 Dart 文案表按由 `nativeLanguage` 派生的 locale 取值；输入语境也按同一字段取值。`LearnPreferences` 只持久化 `nativeLanguage`，旧 `uiLocale` 仅用于迁移和兼容读取。`MaterialApp.locale` 只服务系统控件。两个中文选项继续 `zh-Hant` → `en`；日语选项使用 `ja` → `en`。

**技术栈：** 现有 Flutter Web／Dart、IndexedDB 快照、可选的 `flutter_localizations`（SDK）与 SDK 兼容 `intl`。不新增全局依赖，不改数据库。

**设计依据：** [设置／语言／PWA 设计](../specs/2026-09-10-settings-language-pwa-design.md) 、[项目规范](../../../CLAUDE.md) 。

**当前状态：** 2026-09-10 核心 Web 实施与本地验证已完成；iOS Safari／Android 真机、生产 HTTPS 与 Deno 测试仍是独立待验收项。

## 合并实施补充（2026-09-10，已实施）

- 设置页语言卡片已收口为单一三选一的“母语”：`zh-Hant`、`zh-Hans`、`ja`。界面语言不再单独出现，`uiLocale` 是派生兼容属性。
- 默认值统一为 `zh-Hant`。两个中文脚本都使用中文输入路由（生成 `sourceLanguage: 'zh-Hant'`、转写 `language: 'zh'`）；日本語使用 `sourceLanguage: 'ja'`、转写 `language: 'ja'`。
- 快照只写 `nativeLanguage`；旧双字段快照按显式日本語、旧简体组合、默认繁体的顺序迁移。同步和备份沿用本机选择优先，未新增云端字段或数据库 migration。
- 已有句子、语言元数据、音频缓存和复习数据保持不变；学习语言控件显示英语（可用）与日本語（禁用、标注「之後準備加入」），实际目标语言固定为英语。
- `web_models_test.dart`、`web_l10n_test.dart`、`web_app_test.dart`、`web_controller_test.dart` 已补充统一选择、迁移、输入路由和 UI 切换回归用例；Flutter 全量回归当前为 187 项通过。

## 学习语言控件补充（2026-09-10，已实施）

- 设置页恢复英语／日本語双选项；英语显示为当前可用项，日本語为灰色禁用项，并显示「之後準備加入」。
- 目标语言合约仍固定 `en`，不新增偏好字段；日本語选项仅表达后续规划，点击不会保存或改变当前学习流程。

## 执行记录（2026-09-10）

- [x] T00：确认 Web 代码实施范围，保留循环听及发布边界；决定不新增 `flutter_localizations`／`intl` 或字体依赖，并完成硬编码文案与日语源语言提示词核对。
- [x] T01：统一 `nativeLanguage` 默认值、合法化、旧双字段迁移、快照读写、同步／备份合并保留规则与日语转写／生成映射已实现并通过测试。
- [x] T02：繁体、简体、日语三套应用文案表与键集合测试已完成；输入提示按母语独立选择。
- [x] T03：Material／Cupertino locale 接线、默认繁体启动页、单一母语语言卡片、英语／日本語学习语言控件与刷新持久化已完成。
- [x] T04：Today、聆听循环、练习、笔记、账户、同步、管理台、提示与错误状态均已接入对应文案路径；已有句子内容不随界面或母语切换改变。
- [x] T04a：生成、整理与转写在 `sourceLanguage=ja`／`language=ja` 下的服务端与客户端路由已完成。
- [x] T05：Dart 分析、Flutter 全量测试、Node 浏览器测试与 Release Web 构建已验证；真实设备和 Deno 验证按限制保留未完成状态。

## 1．全局约束

- 仅正式 Web 入口。不改旧原生 Flutter 设置页或 Swift 客户端，除非后续单独授权。
- 本轮文档阶段不改产品代码。实施阶段仍须新的代码授权。
- 统一选择合法值：`zh-Hant`、`zh-Hans`、`ja`。默认 `zh-Hant`，不依据浏览器语言改默认；界面 locale 从该值派生。
- 两个中文值都代表中文输入，生成源语言代码仍为 `zh-Hant`；日语值使用 `ja`。统一选择只改之后的输入语境、转写 `language`、生成 `sourceLanguage` 和应用文案，不改写已有 `LearnSentence.source`／`target`、语言元数据、音频缓存键。
- 只在本机快照持久化 `nativeLanguage`，不写入 `user_profiles`，不新增 migration；旧 `uiLocale` 仅用于兼容迁移。
- 采用官方本地化前，先确认 `flutter_localizations`（SDK）与 `intl: any`，`supportedLocales` 含日语。未确认则用应用文案表，时间选择器可保持现有默认，但必须在验收里标明。
- 新字体（Noto Sans TC／Noto Sans JP）未确认不得打包。先用繁体和日语真实文案做缺字检查。
- 简繁与日语均人工对照，不在运行时翻译，不调用付费 API。
- 对用户开放日语母语开关前，必须先验证生成／整理函数在 `sourceLanguage=ja` 时的输出。prompt 未支持则先改服务端合约，不能让开关发出去却生成中文腔日语或把日语当中文处理。
- 数据库、密钥、CI、公开部署、循环听开发、Web Push 仍按原边界分别确认。

## 2．阶段与依赖

| 阶段 | 任务 | 依赖 | 可审阅产出 |
| --- | --- | --- | --- |
| 开工 | T00 | 新的代码实施授权 | 基线、依赖确认状态 |
| 偏好模型 | T01 | T00 | 单一 `nativeLanguage` 读写、旧双字段迁移、默认繁体、合并规则 |
| 文案表 | T02 | T01 | 繁体／简体／日语键值与缺键失败测试 |
| 应用接线 | T03 | T02；官方本地化若采用需先确认依赖 | MaterialApp locale、设置语言卡片、启动页默认繁体 |
| 覆盖与回归 | T04 | T03 | 引导／学习／错误／管理台文案切换；母语日语新请求；旧句不变 |
| 服务端日语源语言 | T04a | T00，可与 T01—T03 并行 | `sourceLanguage=ja` 的生成／整理合约验证或最小 prompt 修正 |
| 验收 | T05 | T04、T04a | 浏览器核对 L01—L08，记录字体缺口 |

设置页的 PWA 状态改版见 [设置／PWA 计划](2026-09-10-settings-pwa-plan.md)，可并行，但语言卡片文案以本计划为准。

## 3．文件职责

路径相对仓库根目录。均为后续实施范围。

| 文件 | 操作 | 职责 |
| --- | --- | --- |
| `SelahFlutter/lib/web/domain/learning_models.dart` | 修改 | 单一 `nativeLanguage`；旧 `uiLocale` 迁移；非法值回落 `zh-Hant` |
| `SelahFlutter/lib/web/l10n/selah_strings.dart` | 新增 | 应用文案表，按 locale 取值，缺键失败；另提供母语相关输入文案 |
| `SelahFlutter/lib/web/l10n/selah_zh_hant.dart` | 新增 | 繁体文案 |
| `SelahFlutter/lib/web/l10n/selah_zh_hans.dart` | 新增 | 简体文案（可从当前硬编码迁出） |
| `SelahFlutter/lib/web/l10n/selah_ja.dart` | 新增 | 日语文案 |
| `SelahFlutter/lib/web/learning_controller.dart` | 局部修改 | 统一选择更新；派生 locale；生成／转写使用当前输入映射；同步时保留本机选择 |
| `SelahFlutter/lib/web/domain/web_status.dart` | 修改 | 同步状态文案按 locale |
| `SelahFlutter/lib/web/domain/learning_engine.dart` | 修改 | 回忆标题改为键，展示层翻译 |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 修改 | 语言卡片；所有硬编码中文改取值；`MaterialApp.locale` |
| `SelahFlutter/lib/web/ui/admin_dashboard_page.dart` | 修改 | 管理台文案 |
| `SelahFlutter/lib/web/ui/web_start_action.dart` | 修改 | 开始按钮文案 |
| `SelahFlutter/lib/web/ui/plush_companion.dart` | 修改 | 精灵状态说明 |
| `SelahFlutter/web/index.html`、`SelahFlutter/web/manifest.json` | 修改 | 默认繁体 lang 与启动文案 |
| `SelahFlutter/test/web_models_test.dart` | 扩展 | 偏好默认、非法值、备份合并 |
| `SelahFlutter/test/web_app_test.dart` | 扩展 | 默认繁体、切换简体、刷新保持 |
| `SelahFlutter/test/web_l10n_test.dart` | 新增 | 两套文案键完整、句子正文不随 locale 变 |
| `SelahFlutter/pubspec.yaml` | 仅在确认后修改 | `flutter_localizations`、`intl`、`generate: true` |
| `SelahFlutter/l10n.yaml` 与生成文件 | 仅在确认官方本地化后新增 | 只服务 Material／Cupertino 控件，不替代应用文案表 |

### 3.1 共享合约

```dart
const supportedNativeLanguages = ['zh-Hant', 'zh-Hans', 'ja'];
const defaultNativeLanguage = 'zh-Hant';
const supportedUiLocales = supportedNativeLanguages; // derived compatibility alias
const defaultUiLocale = defaultNativeLanguage;

String normalizeNativeLanguage(Object? value) {
  if (value == 'zh-Hant' || value == 'zh-Hans' || value == 'ja') {
    return value as String;
  }
  if (value == 'zh') return 'zh-Hant'; // legacy value
  return 'zh-Hant';
}

String normalizeUiLocale(Object? value) => normalizeNativeLanguage(value);

String generationSourceLanguage(String nativeLanguage) =>
    nativeLanguage == 'ja' ? 'ja' : 'zh-Hant';

String transcriptionLanguage(String nativeLanguage) =>
    nativeLanguage == 'ja' ? 'ja' : 'zh';

String migrateNativeLanguage(Object? nativeLanguage, Object? uiLocale) {
  // Explicit canonical values win. Legacy zh + zh-Hans preserves the old UI.
  if (nativeLanguage == 'ja') return 'ja';
  if (nativeLanguage == 'zh-Hant' || nativeLanguage == 'zh-Hans') {
    return nativeLanguage as String;
  }
  if (nativeLanguage == 'zh' && uiLocale == 'zh-Hans') return 'zh-Hans';
  return 'zh-Hant';
}

class LearnPreferences {
  LearnPreferences({
    this.name = '小豆',
    this.voice = 'gentle-natural',
    this.speed = .85,
    this.onboarded = false,
    this.reminderEnabled = false,
    this.reminderTime = '20:00',
    this.nativeLanguage = defaultNativeLanguage,
    DateTime? updatedAt,
  });
  String nativeLanguage;
  String get uiLocale => nativeLanguage; // derived compatibility view
}

class SelahStrings {
  static SelahStrings of(String uiLocale) => ...;
  String tabToday();
  String settingsLanguageTitle();
  String nativeLanguageLabel();
  String learningLanguageValue(); // 英語／英语／英語
  String todayInputHint(String nativeLanguage);
  String message(String key, [Map<String, String> args]);
}
```

合并规则：若当前账户已有合法 `nativeLanguage`，继续保留；旧快照中的 `uiLocale` 只参与一次迁移。云端缺省或旧备份缺字段不得把用户已选日语或简体打回默认。无字段的旧用户 = 繁体界面＋繁体中文母语选择。

控制器产品提示改为稳定错误码 + 文案表，例如 `LearningFailure('请先登录…', code: 'login_required')`，UI 用 `code` 取值。不能再把中文句子当作唯一 API。过渡期允许 `code` 缺省时按当前 locale 显示 `message`，但新代码必须带 code。

## T00：开工检查

**文件：** 本计划、`CLAUDE.md`、`ROADMAP.md`、设计文档。

- [ ] 确认新指令允许改 Web 产品代码。计划存在不能代替实施授权。
- [ ] 记录将触碰的文件；不覆盖循环听或其他任务的未提交改动。
- [ ] 向主人提交最小依赖说明：`flutter_localizations`（SDK）+ `intl: any`（含 ja）；以及缺字检查后再决定是否增加 Noto Sans TC／Noto Sans JP。未确认则跳过官方本地化和新字体。
- [ ] 清点硬编码中文来源：`web_learning_app.dart`、`learning_controller.dart`、`web_status.dart`、`learning_engine.dart`、`admin_dashboard_page.dart`、`web_start_action.dart`、`plush_companion.dart`、分类／声线常量、`index.html`、`manifest.json`。
- [ ] 只读核对生成／整理 prompt 是否把源语言写死为中文。结论写入 T04a，不在 T00 改服务端。

**完成证据：** 授权、依赖确认状态、文案来源清单可追溯。

## T01：偏好字段与合并

**文件：** `learning_models.dart`、`learning_controller.dart`、`web_models_test.dart`、必要时 `web_controller_test.dart`。

- [x] 先写失败测试并实现：空 JSON → 单一选择为 `zh-Hant`；`zh-Hans`／`ja` 保留；旧双字段按迁移规则转换；非法值回落默认。
- [x] 测试：本机选择为日本語或简体时，云端／备份缺字段的合并不得改回默认；没有字段的旧快照回落繁体中文。
- [x] 实现单一字段的 toJson／fromJson。`updatePreferences(nativeLanguage:)` 校验后写入并更新 `updatedAt`；保留旧 `uiLocale:` 调用的兼容入口。
- [x] 同步合并沿用「本机已改偏好则保留本机」的现有分支；`importGuest` 不覆盖目标账户已有母语选择。
- [x] 纯函数测试：两个中文值均映射 `generationSourceLanguage == 'zh-Hant'`、转写 `language == 'zh'`；日语映射为 `ja`。

运行：`flutter test --no-pub test/web_models_test.dart test/web_controller_test.dart`
预期：新用例通过，旧备份仍可导入。

## T02：文案表

**文件：** `selah_strings.dart`、`selah_zh_hant.dart`、`selah_zh_hans.dart`、`web_l10n_test.dart`。

- [ ] 三套 map 的键集合必须相等。测试遍历键，缺键即失败。
- [ ] 繁体至少覆盖导航「今天／聆聽／練習／筆記／設定」、引导「先讓 Selah 認識你」、设置「語言」「母語」「學習語言」「繁體中文」「简体中文」「日本語」。
- [ ] 简体覆盖当前产品已有对应句，不借机改写语气。
- [ ] 日语覆盖同等键，例如导航「今日／リスニング／練習／ノート／設定」、设置「言語」「母語」「学習言語」。
- [ ] `SelahStrings.of('zh-Hant').tabListen()` 含「聽」；简体为「聆听」；日语为「リスニング」或等价已审定词。
- [ ] 分类、声线、复习／词汇状态、成长阶段、回忆标题全部入表。引擎只保留稳定键。
- [ ] 母语相关输入文案单独按 `nativeLanguage` 取值，不跟界面语言绑死。
- [ ] 占位符用显式替换，如 `syncLastAt(formatted)`，禁止运行时拼半句造成漏译。

运行：`flutter test --no-pub test/web_l10n_test.dart`
预期：三套键对齐；抽样繁体、简体、日语互不相同。

## T03：应用接线与默认繁体

**文件：** `web_learning_app.dart`、`web_entry.dart` 如需、`index.html`、`manifest.json`、`web_app_test.dart`。

- [x] 无偏好时 Widget 测试：`find.text('設定')` 存在，导航中没有简体「设置」、没有日语「ノート」作为默认。
- [x] 选择简体后：导航变为「设置」，`nativeLanguage` 与派生 `uiLocale` 均为 `zh-Hans`。
- [x] 选择日本語后：导航变为日语文案，`nativeLanguage` 与派生 `uiLocale` 均为 `ja`；输入语境同步切换。
- [x] `MaterialApp.locale`：`zh-Hant` → `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`；简体 `Hans`；日语 `Locale('ja')`。`localeListResolutionCallback` 忽略设备语言，只尊重派生 `uiLocale`。
- [ ] 若已确认官方本地化：`supportedLocales` 含繁简日。
- [ ] `index.html`／`manifest.json` 默认繁体。
- [x] 设置语言卡片放在陪伴之前：母語三选项，界面语言由选择派生，学习语言只读英語。
- [x] 选择日本語后，Today 输入标签／占位改为日语语境；两个中文选项保持中文语境。

运行：`flutter test --no-pub test/web_app_test.dart test/web_start_action_test.dart`
预期：引导在繁体默认下仍能完成；旧测试中的简体查找改为走文案表。

## T04：控制器、状态、管理台覆盖

**文件：** `learning_controller.dart`、`web_status.dart`、`admin_dashboard_page.dart`、`plush_companion.dart`、相关测试。

- [x] 产品提示全部经文案表。测试切换统一选择后显示对应语言。
- [ ] 同步胶囊、离线说明、录音失败、生成失败覆盖抽检，含日语界面。
- [ ] 管理台文案纳入同一表。
- [x] 两个中文选择：生成请求仍含 `sourceLanguage: 'zh-Hant'`、`targetLanguage: 'en'`，转写为 `zh`。
- [x] 日本語选择：新的生成／整理／转写发送 `ja`；已有中英句子的 `sourceLanguage` 仍是原值。
- [x] 切换统一选择不改已有句子正文。

运行：`flutter test --no-pub test/web_controller_test.dart test/web_status_test.dart test/web_admin_models_test.dart test/web_l10n_test.dart`

## T04a：日语源语言服务端核对

**文件：** `supabase/functions/_shared/sentence_contract.ts`、`sentences-generate`／`sentences-prepare`／`sentences-batch-generate` 的 prompt 与测试。仅在核对证明必须改合约时才改这些文件；改动单独确认，不顺手改 schema。

- [ ] 用现有 Deno 测试或只读请求记录证明：`sourceLanguage=ja` 会被接受，还是被缺省成 `zh-Hant`。
- [ ] 核对 prompt 是否要求「把中文变成英文」。若写死中文，准备最小修正：源语言为日语时，把用户日语变成自然英文，释义可用日语。
- [ ] 未修正前，设置里的日语母语可以先做数据字段和 UI，但必须禁用生成或显示「日语输入尚未开放」。不得发出会把日语当中文处理的请求。
- [ ] 转写 `language=ja` 已符合现有 LANGUAGE_PATTERN，补客户端测试即可；若服务端有额外中文假设，一并记录。

## T05：验收

- [x] `flutter analyze --no-pub` 无 error；保留 2 条既有 `admin_controller.dart` 风格 info。
- [x] `flutter test --no-pub` 全量通过（187 项）。
- [x] 本地 Release 构建后目视：首次进入繁体＋繁体中文母语；设置页仅有统一三选一；切简体／日本語后界面跟随；选择日本語后输入语境改变，旧句仍在。
- [x] 在本地 Release 的设置与 Today 页面抽查繁体「聽／練／設／語」及日语假名／常用汉字，当前浏览器无缺字；未新增字体依赖。真机字体矩阵仍随设备验收。
- [ ] 不把 iPhone 真机、生产 HTTPS、循环听日语 TTS、学日语课程标进本计划完成项。
- [x] 更新 `ROADMAP.md`：只把已验证项放入已完成，真机与外部环境项仍保持待验收。

**完成证据：** L01—L08 有测试或浏览器记录；依赖／字体／日语 prompt 未确认项保持「待确认」。

| 合约 | 对应任务 |
| --- | --- |
| L01 无偏好默认繁体＋中文母语 | T01 缺省值、T03 首次 Widget／启动页 |
| L02 选择三种母语之一后刷新保持对应界面 | T01 持久化、T03 切换测试 |
| L03 忽略浏览器语言 | T03 localeListResolutionCallback |
| L04 切换界面后句子不变 | T04 句库回归 |
| L05 同步／备份不覆盖本机选择 | T01 合并规则 |
| L06 单一母語三选项与只读学习语言 | T03 语言卡片 |
| L07 日本語只影响新请求 | T04、T04a |
| L08 选择中文／日本語后对应输入语境 | T03 输入语境 |
