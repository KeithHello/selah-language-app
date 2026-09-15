# Selah 循环听最终开发方案 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after the owner explicitly authorizes code changes. Steps use checkbox (`- [ ]`) syntax for tracking. Do not dispatch subagents unless the owner requests it. Do not call TTS, change secrets, run migrations, or deploy.

**Goal:** 让未登录和已登录用户都能使用循环听：自定义停止时间可输入，先准备本机双语音频再开始播放，并按所选语序循环到截止；首次引导改为至少 3 句。

**Architecture:** 继续现有分层。纯 Dart 模型负责队列、时长校验和引导门槛常量；`LearningController` 用 `hasSession` 而不是 `gateway.configured` 决定能不能调用云端生成；`selah_bridge.js` 拥有唯一循环会话、截止时刻和语序切换；页面只读取会话快照。种子双语走本地清单，不把登录墙套在循环听入口上。

**Tech Stack:** Flutter Web / Dart、`dart:js_interop`、HTML `Audio`、Cache API、IndexedDB、现有 Supabase `audio-generate` / `audio-download-url`、`tts-1` MP3。

**Design source:** [循环听最终产品规则](../specs/2026-09-15-loop-listening-final-design.md) 的 R17、R18 以及仍有效的 2026-09-10 S01／S04／S05、R01—R16。旧稿 [2026-09-15-loop-listening-fix-plan.md](2026-09-15-loop-listening-fix-plan.md) 和 [2026-09-10-loop-listening-plan.md](2026-09-10-loop-listening-plan.md) 只作历史参考。

## Global Constraints

- 先不改产品代码；本文件是后续开发的唯一实施入口。主人明确说「去做／实现」之后才按 T1→T7 执行。
- 循环听／重复听不设登录门槛。未登录必须能循环当前句库里已有本机双语音轨的句子。
- 未登录禁止 `audio-generate` 和 `audio-download-url`。判断登录只用 `hasSession`（`gateway.userId != null`），不用 `gateway.configured`。
- 引导至少 3 句，推荐 `seed-001`、`seed-006`、`seed-012`。不改写已引导用户的句库。
- 默认 30 分钟；预设 15／30／60；自定义 1～720 整数分钟。点自定义永远打开输入。
- 从首段真实 `playing` 开始计时；暂停、缓冲、句间隔不延后截止。
- 循环音轨结束不写 `listen_completed`、复习状态或成长奖励。
- 不静默用英文音频、浏览器朗读或 Mock 充当母语。
- 不新增依赖、数据库 schema、密钥、CI 或公开发布。付费补其余种子母语另需独立确认。
- Windows 本机若 `flutter.bat` 因 SDK lockfile 失败，使用 `D:/setup/flutter/bin/cache/dart-sdk/bin/dart.exe --packages=D:/setup/flutter/packages/flutter_tools/.dart_tool/package_config.json D:/setup/flutter/bin/cache/flutter_tools.snapshot test --no-pub <files>`，并申请访问 Flutter SDK 锁文件。
- 当前 `python` 可能被 `uv trampoline ... permission denied` 阻断；本轮不要把 Python 打包器当作通过门槛。

## Current Baseline

已完成、本轮直接复用：

- 聆听页「逐句听／循环听」切换、设置卡、播放卡、迷你播放器入口。
- `LoopOptions`、`buildLoopQueue`、1～720 校验、偏好持久化。
- 独立 `audioLoop*` 会话、1／2 秒间隔、账户切换终止旧会话、学习完成隔离。
- 访客账户 `guest` 校验、缓存键含角色与语言。
- 10 句 starter 及 60 条音频清单：target 用 `seed-xxx:<voice>`，source 用 `seed-xxx:source:zh-Hant|ja`。

已确认仍未修好：

1. 自定义时长弹窗逻辑上不可达：自定义 chip 的 `minutes` 等于当前时长，`selected` 恒为 true。见 `loop_listening_panel.dart` 的 `_durationChip`。
2. 准备与开始绑在 `startLoop()` 里，准备完立刻 `audioLoopStart`。
3. `SupabaseLearningGateway.configured` 恒为 true。访客缺轨时会走进 generate／download，再被 `_requireUser()` 或 JS 异常收成通用粉条。
4. 循环听刷新已有音频用 `get: true`；`_ensureLoopAudio` 拒绝 `http://127.0.0.1`。
5. 暂停改序可能重复当前语言；播放中没有独立截止计时器。
6. 引导仍要求 5 句；推荐 ID 还是已删除的 `seed-003/005/007/009`。
7. 现有 `web_loop_seed_audio_test.dart` 把「startLoop 立即开播」当成功；本轮拆开准备／开始后必须改这个期望。
8. 应用内页可能仍是旧 Build `818ec9378df88fcb`。本地验收前要先更新。

## File Map

| File | Responsibility this round |
| --- | --- |
| `SelahFlutter/lib/web/domain/learning_models.dart` | `minOnboardingSeedCount`、`recommendedOnboardingSeedIds` |
| `SelahFlutter/lib/web/ui/web_start_action.dart` | 开始按钮启用门槛改为 3 |
| `SelahFlutter/lib/web/ui/web_learning_app.dart` | 推荐 3 句、计数颜色门槛、推荐 ID |
| `SelahFlutter/lib/web/learning_controller.dart` | `onboard` 门槛；准备／开始拆开；`hasSession` 守门；POST 刷新；错误映射 |
| `SelahFlutter/lib/web/ui/loop_listening_panel.dart` | 自定义四选一、准备／开始按钮、播放页语序 |
| `SelahFlutter/web/selah_bridge.js` | 独立截止计时器、暂停改序从下一句生效 |
| `SelahFlutter/lib/web/l10n/selah_strings.dart` 及 zh-Hant／zh-Hans／ja | 3 句文案、准备音频、缺音频／登录错误 |
| `SelahFlutter/test/web_start_action_test.dart` | 3 句启用 |
| `SelahFlutter/test/web_app_test.dart` | 引导 3 句与推荐 3 句 |
| `SelahFlutter/test/web_controller_test.dart` | onboard 拒绝 2 句、接受 3 句 |
| `SelahFlutter/test/web_l10n_test.dart` | 三语 3 句文案 |
| `SelahFlutter/test/web_loop_listening_ui_test.dart` | 自定义弹窗、四选一、准备／开始 |
| `SelahFlutter/test/web_loop_controller_test.dart` | 新建：访客可循环、不打云端、准备不自动播 |
| `SelahFlutter/test/web_loop_seed_audio_test.dart` | 改为 prepare 后再 start |
| `SelahFlutter/test/browser_loop_playback.test.mjs` | 暂停改序、无轮询到期停止 |
| `docs/loop-listening-acceptance.md` | 本地证据 |
| `ROADMAP.md` / `CLAUDE.md` | 只记录已验证结果 |

不改：`supabase/functions/audio-generate`、数据库、密钥、`web.ps1` 部署脚本、吉祥物 GIF、已引导用户的 IndexedDB。

## Recommended approach

修现有循环听分层和引导门槛，不重写播放器。原因：产品规则已经在会话模型和 10 句双语包上；缺陷是门槛数字、按钮语义、登录判断和两处桥接状态机。

明确不做：随机播放、白噪音、句库筛选、运行中改时长、未授权批量生成其余母语 MP3、把循环听做成会员功能。

---

### Task 1: Onboarding minimum three sentences

**Files:**
- Modify: `SelahFlutter/lib/web/domain/learning_models.dart` (constants near `currentSourceLanguage`)
- Modify: `SelahFlutter/lib/web/ui/web_start_action.dart:36-44`
- Modify: `SelahFlutter/lib/web/ui/web_learning_app.dart:4245-4283`
- Modify: `SelahFlutter/lib/web/learning_controller.dart:1192-1199`
- Modify: `SelahFlutter/lib/web/l10n/selah_strings.dart`, `selah_zh_hant.dart`, `selah_zh_hans.dart`, `selah_ja.dart`
- Test: `SelahFlutter/test/web_start_action_test.dart`, `web_app_test.dart`, `web_controller_test.dart`, `web_l10n_test.dart`

**Interfaces:**
- Consumes: current 10-sentence starter list
- Produces: `const minOnboardingSeedCount = 3`; `const recommendedOnboardingSeedIds = ['seed-001','seed-006','seed-012']`; `onboard` rejects fewer than 3 unique valid seed ids

- [ ] **Step 1: Write the failing tests**

In `web_start_action_test.dart`, change the threshold cases:

```dart
testWidgets('at least three selected sentences and a name enable one tap', (tester) async {
  var starts = 0;
  await tester.pumpWidget(
    _host(WebStartAction(
      selectedCount: 3,
      hasName: true,
      busy: false,
      onStart: () => starts += 1,
    )),
  );
  expect(find.text('可以開始了'), findsOneWidget);
  await tester.tap(find.byType(FilledButton));
  expect(starts, 1);
});

testWidgets('counts below three stay disabled while larger selections stay enabled', (tester) async {
  for (final count in [0, 2, 3, 5, 6]) {
    await tester.pumpWidget(
      _host(WebStartAction(
        selectedCount: count,
        hasName: true,
        busy: false,
        onStart: _noop,
      )),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null,
      count >= 3,
    );
  }
});
```

In `web_controller_test.dart`:

```dart
test('onboard rejects fewer than three unique seeds', () async {
  final c = LearningController(
    gateway: UnconfiguredGateway(),
    platform: MemoryPlatform(),
    seeds: seeds(),
    polling: false,
  );
  addTearDown(c.dispose);
  await c.initialize();
  await c.onboard('小豆', c.seeds.take(2).map((s) => s.id).toList());
  expect(c.state.preferences.onboarded, false);
  expect(c.state.sentences, isEmpty);
  expect(c.error, '请选择至少三句想学的表达。');
});

test('onboard accepts three or more seeds without an upper limit', () async {
  final c = LearningController(
    gateway: UnconfiguredGateway(),
    platform: MemoryPlatform(),
    seeds: seeds(count: 6),
    polling: false,
  );
  addTearDown(c.dispose);
  await c.initialize();
  await c.onboard('小豆', c.seeds.take(3).map((s) => s.id).toList());
  expect(c.state.preferences.onboarded, true);
  expect(c.state.sentences, hasLength(3));
});
```

In `web_l10n_test.dart`, 简体／繁体／日语的 `onboarding.selectedCount`、`selectTitle`、`recommend` 改为 3 句口径；`translateLegacy('请选择至少三句想学的表达。')` 有繁体和日语译文。

In `web_app_test.dart`:

- 文案 `'已选 0 句（至少 3 句)'`。
- 「推荐 3 句」可点；点后开始按钮在有名字时可用。
- 选满 3 句即可 `onboarded == true`。选 6 句仍然允许，证明没有新的上限。
- 推荐逻辑不得再依赖 `seed-003`。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/web_start_action_test.dart test/web_controller_test.dart test/web_l10n_test.dart test/web_app_test.dart`

Expected: FAIL on the 5-sentence copy, `selectedCount >= 5`, and `请选择至少五句`。

- [ ] **Step 3: Write minimal implementation**

Add to `learning_models.dart` next to `currentSourceLanguage`:

```dart
const minOnboardingSeedCount = 3;
const recommendedOnboardingSeedIds = <String>[
  'seed-001',
  'seed-006',
  'seed-012',
];
```

`WebStartAction._enabled` and the status branch use `minOnboardingSeedCount` instead of `5`。

`onboard`:

```dart
if (seedIds.toSet().length < minOnboardingSeedCount ||
    seedIds.any((id) => !seeds.any((s) => s.id == id || s.seedId == id))) {
  throw const LearningFailure('请选择至少三句想学的表达。');
}
```

推荐按钮：

```dart
onPressed: c.busy || c.seeds.length < minOnboardingSeedCount
    ? null
    : () => setState(() {
        _selected
          ..clear()
          ..addAll(
            c.seeds
                .where((seed) =>
                    recommendedOnboardingSeedIds.contains(seed.seedId))
                .take(minOnboardingSeedCount)
                .map((seed) => seed.seedId!),
          );
        if (_selected.length < minOnboardingSeedCount) {
          _selected
            ..clear()
            ..addAll(
              c.seeds
                  .take(minOnboardingSeedCount)
                  .map((seed) => seed.seedId!),
            );
        }
      }),
```

计数颜色门槛改为 `_selected.length >= minOnboardingSeedCount`。推荐按钮的 `c.seeds.length < 5` 改为 `< minOnboardingSeedCount`。

文案：

| key | zh-Hans | zh-Hant | ja |
| --- | --- | --- | --- |
| `onboarding.selectedCount` | 已选 {count} 句（至少 3 句） | 已選 {count} 句（至少 3 句） | {count}文選択済み（最低3文） |
| `onboarding.description` | …至少三句… | …至少三句… | …3文以上… |
| `onboarding.selectTitle` | 至少挑三句作为开始 | 至少挑三句作為開始 | 最初に3文以上を選ぶ |
| `onboarding.recommend` | 推荐 3 句 | 推薦 3 句 | おすすめ3文 |
| legacy `请选择至少三句想学的表达。` | 同左 | 請選擇至少三句想學的表達。 | 学びたい表現を3文以上選んでください。 |

不要改已引导用户的快照。不要在引导成功后自动开始循环听。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_start_action_test.dart test/web_controller_test.dart test/web_l10n_test.dart test/web_app_test.dart`

Expected: PASS

- [ ] **Step 5: Commit after the owner authorizes code work**

```bash
git add SelahFlutter/lib/web/domain/learning_models.dart SelahFlutter/lib/web/ui/web_start_action.dart SelahFlutter/lib/web/ui/web_learning_app.dart SelahFlutter/lib/web/learning_controller.dart SelahFlutter/lib/web/l10n SelahFlutter/test/web_start_action_test.dart SelahFlutter/test/web_app_test.dart SelahFlutter/test/web_controller_test.dart SelahFlutter/test/web_l10n_test.dart
git commit -m "feat: 引导改为至少三句，并推荐三句有双语包的种子"
```

---

### Task 2: Custom duration four-way exclusive selection

**Files:**
- Modify: `SelahFlutter/lib/web/ui/loop_listening_panel.dart:119-223`
- Test: `SelahFlutter/test/web_loop_listening_ui_test.dart`

**Interfaces:**
- Consumes: `LoopOptions.durationMinutes`, `validateLoopDuration(String)`
- Produces: tapping Custom always opens the dialog; exactly one of 15／30／60／Custom is selected

- [ ] **Step 1: Write the failing Widget test**

Replace the current single happy-path assertion that expects immediate playback. First add:

```dart
testWidgets('custom duration opens even when thirty minutes is selected', (tester) async {
  final controller = _readyController();
  await tester.pumpWidget(MaterialApp(home: WebLearningApp(controller: controller)));
  controller.navigate(1);
  await tester.pump();
  await tester.tap(find.text('循環聽'));
  await tester.pump();

  expect(find.text('30 分鐘'), findsWidgets);
  await tester.tap(find.text('自訂'));
  await tester.pumpAndSettle();

  expect(find.text('自訂時長'), findsOneWidget);
  expect(find.text('請輸入 1～720 分鐘的整數'), findsOneWidget);
});
```

第二项：确认 45 后自定义显示 `自訂 · 45 分鐘`，30 不再选中，再点自定义仍打开且预填 45。

第三项：输入 `721`，弹窗保持打开，仍是 30 分钟。

`_readyController()` 使用已 onboard、至少 1 句、`polling: false` 的控制器；本任务不要求真的开播。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/web_loop_listening_ui_test.dart`

Expected: FAIL because tapping `自訂` does not open a dialog while 30 is selected.

- [ ] **Step 3: Write minimal implementation**

In `_durationChip`:

```dart
final selected = custom
    ? ![15, 30, 60].contains(c.state.preferences.loopOptions.durationMinutes)
    : c.state.preferences.loopOptions.durationMinutes == minutes;

onSelected: (_) {
  if (custom) {
    _openCustomDuration(c.state.preferences.loopOptions.durationMinutes);
  } else {
    c.updateLoopPreferences(durationMinutes: minutes);
  }
}
```

自定义标签：当前是 15／30／60 时显示 `自訂`，否则 `自訂 · N 分鐘`。

删掉从未被设为 true 的 `_customOpen` 日历按钮分支。

弹窗规则：

- 预填当前分钟；即使当前是 30 也预填 30，不要写死 45。
- 非法输入留在弹窗并设置 `loop.durationValidation`。
- 取消／遮罩／Escape 保持原值。
- 确认 15／30／60 时选中对应预设，不显示成自定义。
- `await updateLoopPreferences` 成功后再关；抛错则留在弹窗。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_listening_ui_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/test/web_loop_listening_ui_test.dart
git commit -m "fix: 循环听自定义时长始终可编辑且四选项互斥"
```

---

### Task 3: Loop listening without a login wall

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart:305-470`
- Modify: `SelahFlutter/lib/web/ui/loop_listening_panel.dart:146-166`
- Modify: l10n keys listed below
- Test: Create `SelahFlutter/test/web_loop_controller_test.dart`
- Test: Update `SelahFlutter/test/web_loop_seed_audio_test.dart` so prepare then start is the success path
- Test: Update `SelahFlutter/test/web_loop_listening_ui_test.dart` existing start test

**Interfaces:**
- Consumes: `buildLoopQueue`, `_loopTrackReference`, `_ensureBundledLoopAudio`, `hasSession`
- Produces: guest with bundled bilingual seeds can prepare and start; `prepareLoop()` never calls `audioLoopStart`; `startLoop()` requires a ready queue; unsigned-in never calls `audio-generate` / `audio-download-url` even if `gateway.configured == true`

- [ ] **Step 1: Write failing controller tests**

```dart
class SignedOutConfiguredGateway extends UnconfiguredGateway {
  final calls = <String>[];
  @override
  bool get configured => true;
  @override
  String? get userId => null;
  @override
  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body, {
    bool get = false,
  }) async {
    calls.add(function);
    throw StateError('guest loop must not call $function');
  }
}

class RecordingPlatform implements LearningPlatform {
  final cached = <String>{};
  final actions = <String>[];
  @override
  Future<Object?> invoke(String action, [Map<String, Object?> payload = const {}]) async {
    actions.add(action);
    switch (action) {
      case 'platformInfo':
        return {'online': true};
      case 'contentHash':
        return 'a' * 64;
      case 'audioEnsure':
        cached.add(payload['key'] as String);
        return {'cached': true};
      case 'audioCached':
        return cached.contains(payload['key']);
      case 'audioLoopStart':
        return {
          'state': 'playing',
          'phase': 'target',
          'sentenceIndex': 0,
          'sentenceCount': 1,
          'remainingMs': payload['durationMs'],
        };
      default:
        return null;
    }
  }
}

test('guest with configured gateway still loops bundled bilingual seeds', () async {
  final gateway = SignedOutConfiguredGateway();
  final platform = RecordingPlatform();
  final controller = LearningController(
    gateway: gateway,
    platform: platform,
    polling: false,
    seeds: const [],
    bundledAudio: {
      'seed-001:gentle-natural': {
        'path': 'assets/audio/seed-001-gentle-natural.mp3',
        'sha256': 'b' * 64,
      },
      'seed-001:source:zh-Hant': {
        'path': 'assets/audio/seed-001-source-zh-Hant.mp3',
        'sha256': 'c' * 64,
      },
    },
  );
  controller.state.sentences.add(
    LearnSentence(
      id: 's1',
      seedId: 'seed-001',
      source: '今天又加班到半夜，我真的會謝',
      target: 'Pulled another all-nighter at work. I literally cannot even.',
      sourceLanguage: 'zh-Hant',
    ),
  );
  controller.initialized = true;

  await controller.prepareLoop();
  expect(platform.actions, isNot(contains('audioLoopStart')));
  expect(gateway.calls, isEmpty);
  expect(controller.loopPreparing, isFalse);

  await controller.startLoop();
  expect(platform.actions, contains('audioLoopStart'));
  expect(gateway.calls, isEmpty);
});

test('guest missing personal audio keeps loop UI and does not call generate', () async {
  final gateway = SignedOutConfiguredGateway();
  final controller = LearningController(
    gateway: gateway,
    platform: RecordingPlatform(),
    polling: false,
    seeds: const [],
  );
  controller.state.sentences.add(
    LearnSentence(id: 'personal', source: '我想早点休息。', target: 'I want to rest early.'),
  );
  controller.initialized = true;

  await controller.prepareLoop();
  expect(gateway.calls, isEmpty);
  expect(controller.error, contains('登录'));
  expect(controller.loopPlayback['state'], anyOf('idle', isNull));
});

test('prepareLoop caches missing tracks and does not start audio', () async {
  final platform = RecordingPlatform();
  final controller = LearningController(
    gateway: UnconfiguredGateway(),
    platform: platform,
    polling: false,
    seeds: const [],
    bundledAudio: {
      'seed-001:gentle-natural': {
        'path': 'assets/audio/seed-001-gentle-natural.mp3',
        'sha256': 'b' * 64,
      },
      'seed-001:source:zh-Hant': {
        'path': 'assets/audio/seed-001-source-zh-Hant.mp3',
        'sha256': 'c' * 64,
      },
    },
  );
  controller.state.sentences.add(
    LearnSentence(
      id: 's1',
      seedId: 'seed-001',
      source: '你好。',
      target: 'Hello.',
      sourceLanguage: 'zh-Hant',
    ),
  );
  controller.initialized = true;
  await controller.prepareLoop();
  expect(platform.actions, isNot(contains('audioLoopStart')));
});
```

UI 合同（设计 S01）：

- 缺轨：主按钮 `loop.prepare`／「准备音频」，副文显示缺几句、几段。
- 准备中：按钮禁用，`loop.preparing` 显示 `{done}/{total}`。
- 就绪：按钮变为 `loop.start`／「开始循环听」。准备结束不自动播。
- 未登录时这两个按钮仍然可点，不换成「请先登录」主按钮。登录 CTA 只出现在缺个人音频的错误条。

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/web_loop_controller_test.dart`

Expected: FAIL because `startLoop()` currently prepares and immediately starts, and a configured-but-signed-out gateway would be asked to generate.

- [ ] **Step 3: Write minimal implementation**

Keep `prepareLoop() => _run((generation) => _prepareLoop(generation));`

Change the missing-audio branch inside `_prepareLoop` so it keys off `hasSession`, not `gateway.configured`:

```dart
if (await platform.invoke('audioCached', {
      'accountId': account,
      'key': key,
    }) != true) {
  if (!hasSession) {
    final isSeed = sentence?.seedId != null;
    throw LearningFailure(
      isSeed
          ? '例句的母语音频尚未随应用包就绪，请更新包含例句母语音频的版本。'
          : '登录后就能补齐个人句子的循环听音频。',
      code: isSeed ? 'seed_native_audio_missing' : 'login_required',
    );
  }
  // signed-in restore / generate continues in Task 4
}
```

Change `startLoop()`:

```dart
Future<void> startLoop() => _run((generation) async {
  if (_loopSessionId != null && loopActive) return;
  final ready = await isLoopReady;
  if (!ready) {
    await _prepareLoop(generation);
    _ensureCurrent(generation);
    if (!await isLoopReady) {
      throw const LearningFailure('双语音频尚未准备完成。', code: 'loop_audio_not_ready');
    }
    notice = '双语音频已准备好。';
    return;
  }
  await _beginLoopSession(generation);
});
```

把当前 `audioLoopStart` 块抽到 `_beginLoopSession`。因为 `isLoopReady` 是 async，在 controller 上缓存 `loopReady`，在 prepare、声线变化、句库变化、账户切换后刷新。不要在 `build` 里阻塞首帧。

主按钮：

```dart
onPressed: c.busy || c.loopPreparing
    ? null
    : () async {
        c.clearMessage();
        if (c.loopReady) {
          await c.startLoop();
        } else {
          await c.prepareLoop();
        }
      }
```

循环听面板不得用 `!c.hasSession` 隐藏开始／准备按钮。

Update `web_loop_seed_audio_test.dart`:

```dart
await controller.prepareLoop();
expect(platform.loopStarted, isEmpty);
await controller.startLoop();
expect(platform.loopStarted, hasLength(1));
expect(gateway.called, isFalse);
```

Existing UI test that expects immediate playback must pre-mark tracks cached and `loopReady == true`, or click Prepare then Start.

l10n:

| key | zh-Hant | zh-Hans | ja |
| --- | --- | --- | --- |
| `loop.prepare` | 準備音訊 | 准备音频 | 音声を準備 |
| `loop.prepareHint` | 缺少 {sentences} 句、{tracks} 段雙語音訊 | 缺少 {sentences} 句、{tracks} 段双语音频 | {sentences}文・{tracks}本の音声が未準備です |
| `loop.loginToFillPersonal` | 登入後就能補齊個人句子的循環聽音訊。 | 登录后就能补齐个人句子的循环听音频。 | ログインすると自分の文のループ音声を準備できます。 |

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_controller_test.dart test/web_loop_seed_audio_test.dart test/web_loop_listening_ui_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/lib/web/learning_controller.dart SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/lib/web/l10n SelahFlutter/test/web_loop_controller_test.dart SelahFlutter/test/web_loop_seed_audio_test.dart SelahFlutter/test/web_loop_listening_ui_test.dart
git commit -m "feat: 未登录也可循环听本机双语音频，并先准备再开始"
```

---

### Task 4: POST audio download, local HTTP, honest errors

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart:320-418` and `_message`
- Test: `SelahFlutter/test/web_loop_controller_test.dart`

**Interfaces:**
- Consumes: `gateway.invoke(name, body)` default POST; `hasSession`
- Produces: signed-in restore uses POST; local seed HTTP URLs allowed; JS audio errors not collapsed to the generic pink banner

- [ ] **Step 1: Write the failing test**

```dart
test('signed-in prepareLoop refreshes existing manifests with POST audio-download-url', () async {
  final gateway = _RecordingGateway()
    ..userId = 'user-1'
    ..manifests['loop:voice:source:zh-Hant:hash'] = {'manifestId': 'm1'};
  final controller = _signedInController(gateway: gateway, cached: false);
  await controller.prepareLoop();
  expect(gateway.calls.single.function, 'audio-download-url');
  expect(gateway.calls.single.get, isFalse);
  expect(gateway.calls, isNot(anyElement((c) => c.function == 'audio-generate')));
});

test('prepareLoop maps login, network and seed-native-missing failures', () async {
  // Signed-out + personal sentence => login_required, no cloud call
  // Signed-out + seed without source mp3 => seed_native_audio_missing
  // JS error '音频下载失败' surfaces that text, not the generic preserved-content copy
});

test('local seed http URLs are accepted', () {
  // _ensureLoopAudio / bundled ensure must accept http://127.0.0.1 and http://localhost
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL on `get: true` and generic fallback message.

- [ ] **Step 3: Write minimal implementation**

Only when `hasSession` and bundled/cache miss:

```dart
final response = await gateway.invoke('audio-download-url', {
  'manifestId': manifest!['manifestId'],
});
```

If download fails and the error is not unauthorized, keep the existing manifest id and surface `音频地址刷新失败，请稍后重试。` Do not immediately call `audio-generate` for a known ready manifest.

Only call `audio-generate` when there is no `manifestId` and `hasSession`. Reuse `state.audio[key]['requestId']`. Keep `reason: 'loop_listening'`.

Allow `http://127.0.0.1` and `http://localhost` in `_ensureLoopAudio` and keep using `Uri.base.resolve('assets/' + relative)` for bundled files. Remote signed URLs stay https.

Extend `_message` so these strings pass through: `音频下载失败`、`音频校验失败`、`音频缓存失败`、`音频地址无效`。JS `SelahBridgeError` / `safeError` 文本若已是中文产品句，不要再换成通用粉条。

Map failures:

| code | user-facing |
| --- | --- |
| `login_required` / `unauthorized` | 登录后就能补齐个人句子的循环听音频。 |
| `seed_native_audio_missing` | 例句的母语音频尚未随应用包就绪。 |
| `online_audio_required` | 联网补齐音频后即可循环听。 |
| `quota_exceeded` | keep existing quota copy |
| other | keep generic preserved-content copy, never claim success |

循环听设置卡在 `login_required` 时可以显示现有登录入口，但语序、时长、准备按钮仍在。

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_controller_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/lib/web/learning_controller.dart SelahFlutter/test/web_loop_controller_test.dart
git commit -m "fix: 循环听按登录态刷新音频，并保留明确失败原因"
```

---

### Task 5: Order change from next sentence and independent deadline

**Files:**
- Modify: `SelahFlutter/web/selah_bridge.js:930-1150`
- Modify: `SelahFlutter/lib/web/ui/loop_listening_panel.dart` playing UI
- Test: `SelahFlutter/test/browser_loop_playback.test.mjs`

**Interfaces:**
- Consumes: `audioLoopOrder`, `audioLoopStatus`, session `pendingOrder`
- Produces: paused/playing order changes take effect at the next sentence; timeout stops audio without UI polling

- [ ] **Step 1: Write failing browser tests**

Add to `browser_loop_playback.test.mjs`:

```js
test('changing order while the first target track is paused still finishes source before switching', async () => {
  const env = await prepared();
  await env.call('audioLoopStart', { sessionId: 'order-paused', order: 'targetFirst', durationMs: 60000, tracks: env.tracks, gapMs: { language: 10, sentence: 20 } });
  await env.flush();
  await env.call('audioLoopPause', { sessionId: 'order-paused' });
  await env.call('audioLoopOrder', { sessionId: 'order-paused', order: 'sourceFirst' });
  await env.call('audioLoopResume', { sessionId: 'order-paused' });
  env.root.Audio.lastInstance.emit('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  const status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'order-paused' }));
  assert.equal(status.sentenceIndex, 0);
  assert.equal(status.phase, 'source');
});

test('deadline timer stops playing audio without a status poll', async () => {
  const env = await prepared();
  let pauseCalls = 0;
  const originalPause = env.root.Audio.prototype.pause;
  env.root.Audio.prototype.pause = function () { pauseCalls += 1; return originalPause.call(this); };
  await env.call('audioLoopStart', { sessionId: 'deadline-playing', order: 'targetFirst', durationMs: 60000, tracks: env.tracks });
  await env.flush();
  env.timers.now += 60001;
  const fired = env.fireLatest();
  assert.equal(fired, true);
  const status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'deadline-playing' }));
  assert.equal(status.state, 'ended');
  assert.equal(status.stopReason, 'timeout');
  assert.ok(pauseCalls >= 1);
});
```

Keep the existing next-sentence order test.

- [ ] **Step 2: Run tests to verify they fail**

Run: `node --test test/browser_loop_playback.test.mjs`

Expected: the paused-order test fails with `phase === 'target'` at sentence 0; the deadline test fails because no timer exists while playing.

- [ ] **Step 3: Write minimal implementation**

In `setOrder`:

```js
function setOrder(payload) {
  if (!active || !isCurrent(payload)) return snapshot();
  var order = payload.order === 'sourceFirst' ? 'sourceFirst' : 'targetFirst';
  var atSentenceBoundary = active.trackIndex === 0 && (active.state === 'gap' || active.state === 'starting');
  if (atSentenceBoundary) active.order = order;
  else active.pendingOrder = order;
  return snapshot();
}
```

Do not apply `pendingOrder` in `pause` or `resume`. Apply it only in `onTrackEnded` after both tracks of the current sentence, and in `next()` which already jumps to the next sentence.

Deadline timer:

```js
function armDeadline(session) {
  if (session.deadlineAtMs == null) return;
  var delay = Math.max(0, session.deadlineAtMs - nowMs());
  session.deadlineTimerId = setTimer(function () {
    if (active !== session) return;
    if (nowMs() >= session.deadlineAtMs) finish('timeout');
  }, delay);
}
```

Call `armDeadline(session)` when the first `playing` event sets `deadlineAtMs`. `clearTimers()` must clear this timer. `finish('timeout')` must pause and detach the current element immediately.

Playing UI: reuse the two order buttons; changing order while playing calls `setLoopOrder` and shows `loop.orderNextSentence`. Remaining time, index, count, and phase must come from `loopPlayback`. Count must use `sentenceCount` from the session, not live `state.sentences.length`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test test/browser_loop_playback.test.mjs`

Expected: all previous tests plus the 2 new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/web/selah_bridge.js SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/test/browser_loop_playback.test.mjs
git commit -m "fix: 循环听改序从下一句生效并在播放中独立截止"
```

---

### Task 6: Guest three-sentence bilingual verification

**Files:**
- Test: `SelahFlutter/test/web_loop_controller_test.dart`, `SelahFlutter/test/web_loop_seed_audio_test.dart`
- Create: `docs/loop-listening-acceptance.md`
- Modify packager only if a valid source mp3 is rejected

**Interfaces:**
- Consumes: `seed-xxx:source:zh-Hant` / `seed-xxx:source:ja` bundle entries
- Produces: documented inventory; guest path evidence; no TTS in this task

- [ ] **Step 1: Assert the guest path uses language-suffixed source keys**

```dart
test('bundled source audio uses seed-id:source:zh-Hant and never the English voice file', () async {
  final bundled = {
    'seed-001:gentle-natural': {'path': 'assets/audio/seed-001-gentle-natural.mp3', 'sha256': 'a' * 64},
    'seed-001:source:zh-Hant': {'path': 'assets/audio/seed-001-source-zh-Hant.mp3', 'sha256': 'b' * 64},
  };
  // prepareLoop for a seed sentence must request seed-001-source-zh-Hant.mp3 for the source role
});
```

- [ ] **Step 2: Inspect actual files**

List `SelahFlutter/assets/audio/seed-*-source-zh-Hant.mp3` and `seed-*-source-ja.mp3`. Current expected count is 10 + 10. Record in acceptance: 「种子母语 10／10 中文、10／10 日语；未登录循环听可对这 10 句声称双语完整。」 Do not copy English mp3s to source names. Do not reopen the old 0／30 wording.

- [ ] **Step 3: Local app check after rebuild, still no production deploy**

Rebuild only when the owner authorizes a local web rebuild. Before clicking around, apply the waiting service worker or hard-refresh so the page is not `?v=818ec9378df88fcb`.

Confirm:

- New onboarding: name + 3 recommended sentences can start.
- Guest, not signed in, 循环听 does not ask for login.
- Custom dialog works.
- Prepare then Start on those 3 local sentences.
- Missing source seed shows `seed_native_audio_missing`, not the generic pink banner.

Write evidence paths into `docs/loop-listening-acceptance.md`.

- [ ] **Step 4: Commit docs and wiring tests**

```bash
git add docs/loop-listening-acceptance.md SelahFlutter/test/web_loop_controller_test.dart SelahFlutter/test/web_loop_seed_audio_test.dart
git commit -m "docs: 记录未登录三句循环听双语验收与种子母语库存"
```

---

### Task 7: Regression, local release candidate, and remaining gates

**Files:**
- Modify: `ROADMAP.md`, `CLAUDE.md` only after verification
- Test: affected Flutter tests, Node loop tests, `dart analyze lib/web`

- [ ] **Step 1: Run the required local suite**

```powershell
node --check web/selah_bridge.js
node --test test/browser_loop_playback.test.mjs
flutter test --no-pub test/web_start_action_test.dart test/web_app_test.dart test/web_l10n_test.dart test/web_loop_listening_test.dart test/web_loop_listening_ui_test.dart test/web_loop_controller_test.dart test/web_loop_preferences_test.dart test/web_loop_seed_audio_test.dart test/web_controller_test.dart
dart analyze lib/web
```

Expected: 0 failed tests; analyzer 0 errors. If Flutter SDK lockfile blocks `flutter.bat`, use the dart snapshot command in Global Constraints.

- [ ] **Step 2: Flutter full suite if the targeted tests pass**

Run: `flutter test --no-pub`

Expected: existing suite remains green. Do not mark ROADMAP complete if this cannot run.

- [ ] **Step 3: Local web rebuild only with owner confirmation**

Run: `.\SelahFlutter\tool\web.ps1 -Action build`

Expected: Build ID recorded; public Supabase URL and publishable key present in `main.dart.js` if `.env` has them; OpenAI key absent.

- [ ] **Step 4: Update roadmap with verified facts only**

Move only Tasks 1–5 into completed if tests passed. Keep unchecked:

- Real TTS for personal native audio
- Remaining 20 seed native mp3s
- iPhone Safari / PWA / Android lock-screen 60-minute run
- Cloudflare Pages

- [ ] **Step 5: Commit docs after verification**

```bash
git add ROADMAP.md CLAUDE.md docs/loop-listening-acceptance.md
git commit -m "docs: 同步循环听最终方案的已验证范围与未验收项"
```

---

## Out of scope until separately confirmed

| Item | Why it is separate |
| --- | --- |
| Generate remaining 20 native seed MP3s | Paid TTS, needs quantity and budget |
| Real account T09 AI／TTS／sync | Needs test email and recording sample |
| Safari／PWA／Android lock screen | Device matrix; JS timer passing is not enough |
| Cloudflare Pages | Public deploy red line |
| Media Session lock-screen metadata | Enhancement after the core session is correct |
| Membership quota UX on prepare | Membership mode is currently off; keep existing login/rate limits |
| Rewrite already-onboarded libraries | R18 only changes new onboarding |

## Spec coverage

| Spec | Task |
| --- | --- |
| R18 onboarding minimum 3, recommend 001/006/012 | T1 |
| S04 custom duration, 1–720, cancel keeps old value | T2 |
| R17 guest and signed-in loop; no login wall | T3 |
| S01 prepare then start, no autoplay | T3 |
| R09 cache-complete before ready; no duplicate TTS for existing audio | T3, T4 |
| Honest errors, POST download, local HTTP | T4 |
| R02／R04 order and next-sentence change | T5 |
| R05–R07 first playing starts clock; timeout cuts current track | T5 |
| R13 no listen_completed | already implemented; keep tests in T3 |
| Guest 3-sentence bilingual path | T6 |
| R16 lock-screen 60 min | T7 unchecked gate |

## Execution notes

This document is the only implementation plan for loop listening. Do not reopen [2026-09-10-loop-listening-plan.md](2026-09-10-loop-listening-plan.md) or [2026-09-15-loop-listening-fix-plan.md](2026-09-15-loop-listening-fix-plan.md) as a greenfield rebuild. After the owner says to implement, execute T1→T7 in order with TDD. Paid audio and public deploy stay blocked until separately confirmed.

「重复听」不新增页面或模式，就是循环听。
