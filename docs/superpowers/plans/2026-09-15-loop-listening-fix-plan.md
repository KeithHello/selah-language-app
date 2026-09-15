# Selah 循环听完整修正 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after the owner explicitly authorizes code changes. Steps use checkbox (`- [ ]`) syntax for tracking. Do not dispatch subagents unless the owner requests it. Do not call TTS, change secrets, run migrations, or deploy.

**Goal:** 把现有「循环听」从可进入、会报错的半成品修成：用户能自定义停止时间，能先准备双语音频、再开始播放，并能按所选语序稳定循环到截止时刻。

**Architecture:** 继续沿用现有分层：纯 Dart 模型负责队列与时长校验；`LearningController` 负责账户、准备进度和按钮语义；`selah_bridge.js` 拥有唯一循环会话、截止时刻和语序切换；页面只读取会话快照。本轮不新增数据库表、Edge Function 或 Flutter 依赖。

**Tech Stack:** Flutter Web / Dart、`dart:js_interop`、HTML `Audio`、Cache API、IndexedDB、现有 Supabase `audio-generate` / `audio-download-url`、`tts-1` MP3。

**Design source:** [循环听 UI／UX 设计](../specs/2026-09-10-loop-listening-design.md) 的 R01—R16、S01—S06。旧实施稿 [2026-09-10 循环听整体开发计划](2026-09-10-loop-listening-plan.md) 只作历史参考。

## Global Constraints

- 仅改正式 Web 循环听路径；不重构 Today、练习、笔记、设置、会员或管理台。
- 完整句库＝当前账户已收录、未归档句子；不自动混入未加入的种子目录。
- 默认 `targetFirst`：学习语言 → 1 秒 → 母语 → 2 秒 → 下一句。`sourceFirst` 只交换句内两种语言。
- 默认 30 分钟；预设 15／30／60；自定义 1～720 整数分钟。
- 从首段真实 `playing` 开始计时；暂停、缓冲、句间隔不延后截止；到期立即停当前音轨。
- 循环音轨结束不写 `listen_completed`、复习状态或成长奖励。
- 不静默用英文音频、浏览器朗读或 Mock 充当母语音频。
- 不新增依赖、数据库 schema、密钥、CI 或公开发布。付费 TTS 与母语预制另需独立确认。
- Windows 本机若 `flutter.bat` 因 SDK lockfile 失败，使用 `D:/setup/flutter/bin/cache/dart-sdk/bin/dart.exe --packages=D:/setup/flutter/packages/flutter_tools/.dart_tool/package_config.json D:/setup/flutter/bin/cache/flutter_tools.snapshot test --no-pub <files>`，并申请访问 Flutter SDK 锁文件。

## Current Baseline

已完成、本轮直接复用：

- 聆听页「逐句听／循环听」切换、设置卡、播放卡、迷你播放器入口。
- `LoopOptions`、`buildLoopQueue`、1～720 校验、偏好持久化。
- 独立 `audioLoop*` 会话、1／2 秒间隔、账户切换终止旧会话、学习完成隔离。
- 2026-09-12 访客账户 `guest` 校验、缓存键含角色与语言、活动循环在父级重建后保持播放界面。
- 种子母语清单约定：target 用 `seed-xxx:<voice>`，source 用 `seed-xxx:source`；打包脚本已能识别 `seed-xxx-source.mp3`。

已确认仍未修好：

1. 自定义时长点击无弹窗，且与 30 分钟同时显示选中。根因：自定义 chip 用当前时长与自身比较，永远 `selected=true`，而打开弹窗的条件是 `custom && !selected`。见 [loop_listening_panel.dart](../../../SelahFlutter/lib/web/ui/loop_listening_panel.dart:196)。
2. 准备与开始仍绑在同一个按钮；`startLoop()` 内部直接调用 `_prepareLoop()`，准备完成后立即 `audioLoopStart`。见 [learning_controller.dart](../../../SelahFlutter/lib/web/learning_controller.dart:419)。
3. 循环听恢复已有音频用 `get: true`，`audio-download-url` 只接受 POST。普通单句播放已用 POST。见 [learning_controller.dart](../../../SelahFlutter/lib/web/learning_controller.dart:341) 与 [audio-download-url/index.ts](../../../supabase/functions/audio-download-url/index.ts:24)。
4. 暂停后改语序可能重复播放当前语言。根因：`setOrder()` 在 `paused` 时立即改 `order`，但 `trackIndex` 仍指向旧句内位置。已用浏览器桥接模拟复现。见 [selah_bridge.js](../../../SelahFlutter/web/selah_bridge.js:1121)。
5. 正在播放时没有独立截止计时器；到期依赖 UI 轮询 `audioLoopStatus`。关闭轮询后，`playing` 状态不会自行停止。见 [selah_bridge.js](../../../SelahFlutter/web/selah_bridge.js:930)。
6. 播放页没有语序控件；语言名和句数取自当前设置／全库，不是会话快照。
7. 现有 Widget 测试把音频已缓存、空网关、立即开始当作成功路径，覆盖不了自定义弹窗、缺音频准备、GET／POST 或暂停改序。
8. 30 个种子母语 MP3 仍不存在。`seed-audio.json` 不得把英文文件登记为 `:source`。

2026-09-11 曾判断 `startLoop()` 因嵌套 `_run()` 被 `busy` 拦截。当前代码已改为 `startLoop()` 调 `_prepareLoop(generation)`，这一条不再作为本轮主缺陷。

## File Map

| File | Responsibility this round |
| --- | --- |
| `SelahFlutter/lib/web/ui/loop_listening_panel.dart` | 自定义时长四选一、准备／开始按钮、播放页语序、会话快照展示 |
| `SelahFlutter/lib/web/learning_controller.dart` | 准备与开始拆开、POST 下载、明确错误码、会话快照字段 |
| `SelahFlutter/web/selah_bridge.js` | 独立截止计时器、暂停改序从下一句生效、到期立即停音频 |
| `SelahFlutter/lib/web/l10n/selah_zh_hant.dart` / `selah_zh_hans.dart` / `selah_ja.dart` | 准备音频、下一句生效、缺音频／登录／网络错误文案 |
| `SelahFlutter/test/web_loop_listening_ui_test.dart` | 自定义弹窗、四选一、准备／开始分离 |
| `SelahFlutter/test/web_loop_controller_test.dart` | 新建：准备不自动播放、POST 下载、缺音频、账户切换 |
| `SelahFlutter/test/browser_loop_playback.test.mjs` | 暂停改序、无轮询到期停止 |
| `docs/loop-listening-acceptance.md` | 本地与真机证据；未验证项分开写 |
| `ROADMAP.md` / `CLAUDE.md` | 只记录本轮已验证结果 |

不改：`supabase/functions/audio-generate`、数据库、密钥、`web.ps1` 部署脚本、吉祥物 GIF。

## Recommended approach

修现有循环听分层，不重写播放器，不引入 Web Audio／新 TTS。原因：产品规则已写进现有会话模型；缺陷集中在按钮语义、HTTP 方法和两处桥接状态机。Media Session 与锁屏续播仍是增强项，不能代替独立截止计时器。

明确不做：随机播放、白噪音、句库筛选、运行中改时长、新增循环统计表、未授权批量生成 120 段母语 MP3。

---

### Task 1: Custom duration four-way exclusive selection

**Files:**
- Modify: `SelahFlutter/lib/web/ui/loop_listening_panel.dart:119-223`
- Test: `SelahFlutter/test/web_loop_listening_ui_test.dart`

**Interfaces:**
- Consumes: `LoopOptions.durationMinutes`, `validateLoopDuration(String)`
- Produces: tapping Custom always opens the dialog; exactly one of 15／30／60／Custom is selected

- [ ] **Step 1: Write the failing Widget test**

Replace the current single happy-path test file content with tests that use the real panel. First test:

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

Add a second test: confirm 45, then Custom shows `自訂 · 45 分鐘`, 30 is not selected, tapping Custom opens again with `45`.

Add a third test: enter `721`, confirm stays closed-invalid, previous 30 remains.

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

Custom chip label: if current minutes is 15／30／60, show `自訂`; otherwise `自訂 · N 分鐘`.

Keep four chips visible. Delete the unused `_customOpen` branch that replaces the chip row with a calendar button.

Dialog rules:

- Prefill current minutes; if current is 15／30／60, still prefill that number, not a hardcoded 45.
- Invalid input keeps the dialog open and sets `loop.durationValidation`.
- Cancel / barrier / Escape leave the previous value.
- Confirm 15／30／60 selects that preset chip, not Custom.
- Await `updateLoopPreferences` before closing; if it throws, keep the dialog and show the controller error.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_listening_ui_test.dart`

Expected: PASS

- [ ] **Step 5: Commit after the owner authorizes code work**

```bash
git add SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/test/web_loop_listening_ui_test.dart
git commit -m "fix: 循环听自定义时长始终可编辑且四选项互斥"
```

---

### Task 2: Split prepare and start

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart:285-450`
- Modify: `SelahFlutter/lib/web/ui/loop_listening_panel.dart:146-166`
- Modify: `SelahFlutter/lib/web/l10n/selah_zh_hant.dart`, `selah_zh_hans.dart`, `selah_ja.dart`
- Test: `SelahFlutter/test/web_loop_controller_test.dart` (create)

**Interfaces:**
- Consumes: `buildLoopQueue`, `_loopTrackReference`, `platform.invoke('audioCached')`
- Produces: `prepareLoop()` never calls `audioLoopStart`; `startLoop()` requires a ready queue for the current voice

- [ ] **Step 1: Write failing controller tests**

```dart
test('prepareLoop caches missing tracks and does not start audio', () async {
  final platform = _RecordingPlatform();
  final controller = LearningController(gateway: _ReadyGateway(), platform: platform, polling: false, seeds: const []);
  controller.state.sentences.add(LearnSentence(id: 's1', source: '你好。', target: 'Hello.'));
  controller.initialized = true;

  await controller.prepareLoop();

  expect(platform.actions, isNot(contains('audioLoopStart')));
  expect(controller.loopPlayback['state'], anyOf('idle', 'ready'));
  expect(controller.loopPreparing, isFalse);
});
```

UI contract to implement, matching design S01:

- Missing tracks: primary button label is `loop.prepare` / 「准备音频」, subtitle shows missing sentence count and track count.
- Preparing: button disabled, text `loop.preparing` with `{done}/{total}`.
- Ready: button becomes `loop.start` / 「开始循环听」. Do not autoplay when prepare finishes.
- Repeat start while a session is active does not create a second session.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/web_loop_controller_test.dart`

Expected: FAIL because `startLoop()` currently always prepares and immediately starts.

- [ ] **Step 3: Write minimal implementation**

Keep `prepareLoop() => _run((generation) => _prepareLoop(generation));`

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
    return; // first click with missing audio only prepares
  }
  await _beginLoopSession(generation);
});
```

If the implementer prefers two explicit buttons instead of one button that changes label, that is allowed only if the ready state still requires a separate user click to play. Do not autoplay after a long prepare.

Primary button in the panel:

```dart
onPressed: c.busy || c.loopPreparing
    ? null
    : () async {
        c.clearMessage();
        if (await c.isLoopReady) {
          await c.startLoop();
        } else {
          await c.prepareLoop();
        }
      }
```

Because `isLoopReady` is async, cache a `loopReady` boolean on the controller and refresh it after prepare, voice change, sentence change, and account change. Do not block the first frame on a platform round-trip inside `build`.

Add l10n keys:

| key | zh-Hant | zh-Hans | ja |
| --- | --- | --- | --- |
| `loop.prepare` | 準備音訊 | 准备音频 | 音声を準備 |
| `loop.prepareHint` | 缺少 {sentences} 句、{tracks} 段雙語音訊 | 缺少 {sentences} 句、{tracks} 段双语音频 | {sentences}文・{tracks}本の音声が未準備です |
| `loop.orderNextSentence` | 下一句起使用{order} | 下一句起使用{order} | 次の文から{order} |

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_controller_test.dart test/web_loop_listening_ui_test.dart`

Expected: PASS. Existing UI test that expects immediate playback must be updated: either pre-mark tracks cached and ready, or click Prepare then Start.

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/lib/web/learning_controller.dart SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/lib/web/l10n SelahFlutter/test/web_loop_controller_test.dart SelahFlutter/test/web_loop_listening_ui_test.dart
git commit -m "fix: 循环听先准备双语音频，再由用户开始播放"
```

---

### Task 3: POST audio download and honest prepare errors

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart:320-385`
- Test: `SelahFlutter/test/web_loop_controller_test.dart`

**Interfaces:**
- Consumes: `gateway.invoke(name, body)` default POST
- Produces: loop restore uses the same POST as single-sentence play; generate only when no manifest exists

- [ ] **Step 1: Write the failing test**

```dart
test('prepareLoop refreshes existing manifests with POST audio-download-url', () async {
  final gateway = _RecordingGateway()
    ..manifests['loop:voice:source:zh-Hant:hash'] = {'manifestId': 'm1'};
  final controller = _controller(gateway: gateway, cached: false);
  await controller.prepareLoop();
  expect(gateway.calls.single.function, 'audio-download-url');
  expect(gateway.calls.single.get, isFalse);
  expect(gateway.calls, isNot(anyElement((c) => c.function == 'audio-generate')));
});

test('prepareLoop maps login, network and seed-native-missing failures', () async {
  // Unconfigured + personal sentence => online_audio_required
  // Unconfigured + seed without source mp3 => seed_native_audio_missing
  // 401 from download => unauthorized
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL on `get: true`.

- [ ] **Step 3: Write minimal implementation**

Change the loop restore call to match single-sentence play:

```dart
final response = await gateway.invoke('audio-download-url', {
  'manifestId': manifest!['manifestId'],
});
```

If download fails and the error is not unauthorized, keep the existing manifest id and surface `音频地址刷新失败，请稍后重试。` Do not immediately call `audio-generate` for a known ready manifest.

Only call `audio-generate` when there is no `manifestId` and the user is signed in. Reuse `state.audio[key]['requestId']`. Keep `reason: 'loop_listening'`.

Allow `http://127.0.0.1` and `http://localhost` in `_ensureLoopAudio` for bundled seed files served by the local static server; keep `https` for remote signed URLs. Current code rejects non-https, which would break local seed source files after `Uri.base.resolve(relative)`.

Map failures:

| code | user-facing |
| --- | --- |
| `login_required` / `unauthorized` | 登录后就能补齐循环听音频。 |
| `seed_native_audio_missing` | 例句的母语音频尚未随应用包就绪。 |
| `online_audio_required` | 联网补齐音频后即可循环听。 |
| `quota_exceeded` | keep existing quota copy |
| other | keep generic preserved-content copy, never claim success |

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/web_loop_controller_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/lib/web/learning_controller.dart SelahFlutter/test/web_loop_controller_test.dart
git commit -m "fix: 循环听按 POST 刷新已有音频并保留明确失败原因"
```

---

### Task 4: Order change from next sentence and independent deadline

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

Expected: all previous 4 tests plus the 2 new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add SelahFlutter/web/selah_bridge.js SelahFlutter/lib/web/ui/loop_listening_panel.dart SelahFlutter/test/browser_loop_playback.test.mjs
git commit -m "fix: 循环听改序从下一句生效并在播放中独立截止"
```

---

### Task 5: Local bilingual verification without silent English fallback

**Files:**
- Modify: `SelahFlutter/tool/package_seed_audio.py` only if the local packager rejects valid source mp3s
- Test: `SelahFlutter/test/web_loop_controller_test.dart`, existing packager tests
- Create: `docs/loop-listening-acceptance.md`

**Interfaces:**
- Consumes: `seed-xxx:source` bundle entries
- Produces: documented inventory; no TTS in this task

- [ ] **Step 1: Write failing inventory assertion in acceptance notes and a controller test**

```dart
test('bundled source audio uses seed-id:source and never the English voice file', () async {
  final bundled = {
    'seed-001:gentle-natural': {'path': 'assets/audio/seed-001-gentle-natural.mp3', 'sha256': 'a' * 64},
    'seed-001:source': {'path': 'assets/audio/seed-001-source.mp3', 'sha256': 'b' * 64},
  };
  // prepareLoop for a seed sentence must request seed-001-source.mp3 for the source role
});
```

- [ ] **Step 2: Inspect actual files**

List `SelahFlutter/assets/audio/seed-*-source.mp3`. If the count is 0, record in acceptance: 「种子母语 0／30，未登录循环听不能声称双语完整。」 Do not copy English mp3s to source names.

- [ ] **Step 3: Implement only wiring gaps**

If source files exist, run:

```powershell
python SelahFlutter/tool/package_seed_audio.py --local
```

Expected: `seed-audio.json` contains 120 English voice entries plus N source entries, each source path ending with `-source.mp3`.

If files do not exist, skip packager write. Logged-in personal sentences still use `audio-generate` with the source text; that path is verified with mocks here, real TTS later.

- [ ] **Step 4: Local app check after rebuild, still no production deploy**

Rebuild only when the owner authorizes a local web rebuild. Confirm:

- Custom dialog works.
- Prepare then Start on 3 local sentences.
- Missing source seed shows `seed_native_audio_missing`, not a generic crash.

Write evidence paths into `docs/loop-listening-acceptance.md`.

- [ ] **Step 5: Commit docs and any packager/test wiring**

```bash
git add docs/loop-listening-acceptance.md SelahFlutter/test/web_loop_controller_test.dart
git commit -m "docs: 记录循环听双语准备验收与种子母语库存"
```

---

### Task 6: Regression, local release candidate, and remaining gates

**Files:**
- Modify: `ROADMAP.md`, `CLAUDE.md` only after verification
- Test: affected Flutter tests, Node loop tests, `dart analyze lib/web`

- [ ] **Step 1: Run the required local suite**

```powershell
node --check web/selah_bridge.js
node --test test/browser_loop_playback.test.mjs
flutter test --no-pub test/web_loop_listening_test.dart test/web_loop_listening_ui_test.dart test/web_loop_controller_test.dart test/web_loop_preferences_test.dart
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

Move only Tasks 1–4 into completed if tests passed. Keep unchecked:

- Real TTS for personal native audio
- 30 seed native mp3s
- iPhone Safari / PWA / Android lock-screen 60-minute run
- Cloudflare Pages

- [ ] **Step 5: Commit docs after verification**

```bash
git add ROADMAP.md CLAUDE.md docs/loop-listening-acceptance.md
git commit -m "docs: 同步循环听修正的已验证范围与未验收项"
```

---

## Out of scope until separately confirmed

| Item | Why it is separate |
| --- | --- |
| Generate 30×4 native seed MP3s | Paid TTS, needs quantity and budget |
| Real account T09 AI／TTS／sync | Needs test email and recording sample |
| Safari／PWA／Android lock screen | Device matrix; JS timer passing is not enough |
| Cloudflare Pages | Public deploy red line |
| Media Session lock-screen metadata | Enhancement after the core session is correct |
| Membership quota UX on prepare | Membership mode is currently off; keep existing login/rate limits |

## Spec coverage

| Spec | Task |
| --- | --- |
| S04 custom duration, 1–720, cancel keeps old value | T1 |
| S01 prepare then start, no autoplay | T2 |
| R09 cache-complete before ready; no duplicate TTS for existing audio | T2, T3 |
| R02／R04 order and next-sentence change | T4 |
| R05–R07 first playing starts clock; timeout cuts current track | T4 |
| R13 no listen_completed | already implemented; keep tests in T2 |
| R16 lock-screen 60 min | T6 unchecked gate |
| Seed native inventory | T5 |

## Execution notes

This document is the only implementation plan for the loop-listening fix. Do not reopen [2026-09-10-loop-listening-plan.md](2026-09-10-loop-listening-plan.md) as a greenfield rebuild. After the owner says to implement, execute T1→T6 in order with TDD. Paid audio and public deploy stay blocked until separately confirmed.
