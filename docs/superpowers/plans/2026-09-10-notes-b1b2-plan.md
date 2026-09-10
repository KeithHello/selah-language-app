# Selah 笔记 B1＋B2 开发计划

> 面向后续执行者：取得笔记页代码实施授权后，使用 `executing-plans` 技能逐任务执行与验收。所有复选框代表未来工作，本计划不触发自动实施、agent 分派、付费调用或部署。

**目标：** 正式 Web「笔记」改为完整双语卡片。用户打开即可确认整句英文，可点已有词汇查看释义，可在原卡片展开／收起拆解，并继续听或练这一句。

**架构：** 继续用 `LearningController` 管理句子、词汇状态和跨页选中。笔记页只保存搜索、分类、展开 ID 集合和当前词面板 ID。展示组件从截断 `ListTile` 换成卡片；不改 `LearnSentence` 字段，不新增同步事件。

**技术栈：** 现有 Flutter Web／Dart、现有设计 token、现有三语文案表；不新增 Flutter 或全局依赖。

**设计依据：** [UI／UX 设计](../specs/2026-09-10-notes-b1b2-design.md) 、[方案对照](../specs/2026-09-10-notes-b1b2-ui-overview.png) 、[网页稿](../specs/2026-09-10-notes-b1b2-ui-desktop.png) 、[手机稿](../specs/2026-09-10-notes-b1b2-ui-mobile.png) 、[项目规范](../../../CLAUDE.md) 。

**当前状态：** 2026-09-10 已完成核心 Web 实施与专项验收；全量 Flutter 回归、release 构建、真实浏览器视口和真机验收因环境额度限制待补，记录见 `docs/notes-b1b2-acceptance.md`。

## 1．全局约束

- 仅正式 Web 入口 `SelahFlutter/lib/web/ui/web_learning_app.dart`；不改旧原生 Flutter 与 Swift 客户端。
- 本轮允许按主人确认的范围修改正式 Web 笔记代码、测试和验收文档；不得修改数据库 schema、密钥、CI、依赖或部署。
- 列表英文不得 `maxLines: 1` 截断；宽屏取消空的「选一句查看详情」。
- 只高亮已有 `vocabulary` 条目，不把每个单词变成按钮。
- 允许同时展开多张卡片；禁止手风琴互斥。
- 听这句／练这句只做选中和跳转，不把笔记页点击记为聆听或练习完成。
- 成长回忆入口保持隐藏。
- 界面文案走 `SelahStrings` 三语表；源文案用简体键，繁体／日语同步补齐。
- 复用 `setVocabularyState`、`selectSentence`、`navigate`、`markPreviewed`；不新增云端字段。

## 2．文件与职责

| 文件 | 职责 |
| --- | --- |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 在原笔记段实现笔记页、卡片、词面板和展开区；保留壳层导航、成长回忆开关和其他页面 |
| `SelahFlutter/lib/web/l10n/selah_strings.dart` | 新增／修订笔记文案 |
| `SelahFlutter/test/web_app_test.dart` | 从正式入口覆盖完整双语、展开、点词、空状态、成长回忆仍隐藏 |
| `SelahFlutter/test/web_notes_page_test.dart` | 新增卡片交互的焦点测试：多卡同时展开、无词汇／无拆解、滚动位置 |
| `docs/notes-b1b2-acceptance.md` | 实施后记录浏览器视口与真机结果；本计划创建时不要提前写通过 |

若实施时判断迁出风险高于收益，允许把新卡片直接写在 `web_learning_app.dart`，但测试仍按正式入口 `WebLearningApp` 编写，不能只测孤立组件。

## 3．关键接口

笔记页 UI 状态（仅内存，不序列化）：

```dart
class NotesViewState {
  String query = '';
  String category = 'all';
  final Set<String> expandedIds = <String>{};
  String? activeVocabularyId;
}
```

重点表达选择：

```dart
VocabularyEntry? featuredVocabulary(LearnSentence sentence) {
  return sentence.vocabulary.isEmpty ? null : sentence.vocabulary.first;
}

List<({int start, int end, VocabularyEntry entry})> vocabularySpans(
  String target,
  List<VocabularyEntry> vocabulary,
) {
  // 大小写不敏感；同一位置只保留最长匹配；每词只标第一次出现。
}
```

现有控制器入口保持签名：

```dart
void selectSentence(LearnSentence sentence);
void navigate(int index); // 1 聆听，2 练习
Future<bool> setVocabularyState(LearnSentence sentence, VocabularyEntry entry, String value, {String? expectedState});
Future<void> markPreviewed(List<LearnSentence> sentences);
```

## 4．任务

### T00：确认实施授权与基线

**文件：** `CLAUDE.md`、`ROADMAP.md`、工作区状态。

- [x] 确认主人已明确要求实施笔记 B1＋B2，而不是继续停留在文档。
- [x] 记录当前 `git status` 与本任务将触碰的文件；不覆盖其他任务未提交改动。
- [x] 确认不安装依赖、不改 `.env`、不做 migration 或部署。

**完成证据：** 授权范围可追溯；未把循环听、会员、设置任务卷进来。

### T01：先写失败测试

**文件：** `SelahFlutter/test/web_app_test.dart`、`SelahFlutter/test/web_notes_page_test.dart`。

用 3 句真实结构的 `LearnSentence`：一句含词汇和拆解，一句只有正文，一句无匹配搜索。

```dart
testWidgets('notes show complete bilingual cards without selecting first', (tester) async {
  controller.state.preferences.onboarded = true;
  controller.state.sentences.addAll([
    _seed(1)
      ..source = '老闆又在開空頭支票。'
      ..target = 'My boss is making empty promises again.'
      ..vocabulary.add(VocabularyEntry(id: 'v1', text: 'empty promises', meaning: '不會兌現的承諾')),
    _seed(2)
      ..source = '今天又要加班到很晚。'
      ..target = 'I have to work late again today.',
  ]);
  controller.navigate(3);
  await tester.pumpWidget(WebLearningApp(controller: controller));
  await tester.pumpAndSettle();

  expect(find.text('My boss is making empty promises again.'), findsOneWidget);
  expect(find.text('I have to work late again today.'), findsOneWidget);
  expect(find.text('选一句查看详情'), findsNothing);
  expect(find.text('Boss is making empty promises again. ...'), findsNothing);
});
```

- [x] 写失败测试：完整双语可见；不再出现「选一句查看详情」。
- [x] 写失败测试：点「展开拆解」后拆解在原卡片内，第二句英文仍在。
- [x] 写失败测试：两张卡片可同时展开。
- [x] 写失败测试：点 `empty promises` 只打开该词释义，不跳转聆听。
- [x] 写失败测试：无词汇无拆解的句子没有「重点表达」和「展开拆解」。
- [x] 写失败测试：空库／无匹配沿用现有空状态。
- [x] 保留并继续通过「notes page hides the growth memories entry card」。
- [x] 运行专项：`flutter test --no-pub test/web_app_test.dart test/web_notes_page_test.dart`
  预期：新用例 FAIL，因为卡片尚未替换列表。

### T02：补笔记文案

**文件：** `SelahFlutter/lib/web/l10n/selah_strings.dart`、`SelahFlutter/test/web_l10n_test.dart`。

- [x] 新增源文案：`回看句子，慢慢熟悉每个表达。`、`重点表达`、`听这句`、`练这句`、`展开拆解`、`收起拆解`、`标记熟悉`。
- [x] 为 `zh-Hant` 和 `ja` 补对应翻译；没有把概念图里的「隨聽／空頭承諾」错字带入产品文案。
- [x] 繁体覆盖：`把學過的留下來`、`聽這句`、`展開拆解`、`收起拆解`、`重點表達`。
- [x] 现有 `review.*` 与 `vocab.*` 语义未改。
- [x] 运行相关 l10n 测试，确认缺键不会回退成空白。

### T03：实现双语卡片与展开

**文件：** `SelahFlutter/lib/web/ui/notes_page.dart` 或 `web_learning_app.dart` 笔记段。

- [x] 删除笔记列表英文 `maxLines: 1` 和宽屏空详情。
- [x] 用垂直卡片列表替换 `_NotesList`＋`_NoteDetail` 的默认路径。
- [x] 卡片默认渲染完整 `source`／`target`、分类、`reviewLabel`、可选重点表达、「听这句」「展开拆解」。
- [x] `expandedIds` 控制拆解区；收起不丢搜索和分类。
- [x] 「听这句」→ `selectSentence`＋`navigate(1)`；「练这句」→ `selectSentence`＋`navigate(2)`。
- [x] 夜间预览保留在展开后的次要位置，继续调用 `markPreviewed`。
- [x] Reduce Motion 下展开无高度动画。
- [x] 运行 T01 中除点词外的专项测试并通过。

### T04：实现点词面板

**文件：** 同 T03，加 `vocabularySpans` 纯函数测试。

```dart
test('vocabularySpans highlights the longest first match only', () {
  final spans = vocabularySpans('My boss is making empty promises again.', [
    VocabularyEntry(id: 'a', text: 'empty', meaning: '空的'),
    VocabularyEntry(id: 'b', text: 'empty promises', meaning: '不會兌現的承諾'),
  ]);
  expect(spans, hasLength(1));
  expect(spans.single.entry.id, 'b');
});

test('vocabularySpans stays empty when the phrase is absent', () {
  final spans = vocabularySpans('See you tomorrow.', [
    VocabularyEntry(id: 'a', text: 'empty promises', meaning: '不會兌現的承諾'),
  ]);
  expect(spans, isEmpty);
});
```

- [x] 先让上述纯函数测试失败，再实现匹配。
- [x] 句中匹配片段可点击；无匹配时不画假下划线，重点表达行仍可打开词面板。
- [x] 词面板显示 text、meaning、状态和下一步；调用 `setVocabularyState`。
- [x] 同一卡片只打开一个词面板；关闭后滚动位置不变。
- [x] 匹配片段由 InkWell 提供键盘焦点和 Enter／Space 激活语义。
- [x] 运行点词相关专项测试并通过。

### T05：空状态、筛选与会话内返回

**文件：** 笔记页、`web_app_test.dart`。

- [x] 保留搜索中英、分类芯片、「还没有笔记」「没有匹配的句子」。
- [x] 从笔记切到今天再回来时，同会话内保留搜索、分类、展开集合；账户切换时清空。
- [x] 搜索图标保持无动作装饰，避免假筛选。
- [x] 成长回忆继续由 `_growthMemoriesUiEnabled` 隐藏。
- [x] 补测试：无匹配空状态；隐藏成长回忆仍成立。

### T06：视口、可访问性与构建验收

**文件：** 笔记页、`docs/notes-b1b2-acceptance.md`（实施后才写结果）。

- [x] 在 Widget 测试中覆盖 320／390／768／1130／1440 逻辑像素并检查无异常。
- [x] 在 Widget 测试中确认 390px 下第一张卡片操作仍可滚动到并可见。
- [x] 在 Widget 测试中覆盖 200％文字缩放下的「听这句」操作。
- [x] 按现有 Quiet Growth token 核对主文本、薰衣草重点和按钮层级；未改动全局对比度 token。
- [x] 运行最终环境命令：

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release
```

结果：analyze 无错误但保留 2 条既有 admin info；全量测试 181 项通过；Release 构建成功，Build ID 和 Widget 视口检查已写入验收文档。真实浏览器视口、iPhone Safari／Android 真机仍标记为「未验收」，不得用桌面缩小视口代替真机结果。

## 5．验收对照

| 设计编号 | 计划任务 |
| --- | --- |
| N01 完整双语、无空详情栏 | T01、T03 |
| N02 手机完整阅读 | T06 |
| N03／N04 原卡片展开且可多开 | T01、T03 |
| N05 点词不跳页 | T04 |
| N06 关闭后保留位置 | T04、T05 |
| N07／N08 听这句／练这句 | T03 |
| N09 无词汇无拆解 | T01、T03 |
| N10 空状态 | T05 |
| N11 视口与缩放 | T06 |
| N12 成长回忆仍隐藏 | T01、T05 |

## 6．明确不做

- 不实施 B4 日期分组、B3 作为默认详情层。
- 不恢复成长回忆入口。
- 不新增数据库字段、会员校验或循环听改动。
- 不把概念图当作像素级视觉稿强制还原装饰性错字、虚构日期或侧栏口号。

## 7．执行交接

计划已保存。取得实施授权后有两种执行方式：

1. Subagent-Driven：每任务一个新代理，任务间审查。
2. Inline Execution：本会话按 `executing-plans` 逐项执行并设检查点。

实施授权已获得；最终环境命令和真实设备验收完成前，仍不得把路线图标为全部完成。
