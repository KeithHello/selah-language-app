# Web Performance Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce idle CPU use, tab-switch rebuilds, large Notes-page work, and startup delay in the Flutter Web app.

**Architecture:** Keep the existing Flutter Web architecture and data model. Stop the mascot's frame loop after a short entrance, isolate `MaterialApp` updates from routine learning-state notifications, retain stale child widgets for inactive tabs until they become active, virtualize Notes cards, and expose browser performance marks around startup milestones. Move account initialization behind the first Flutter frame; keep local snapshot loading ahead of scheduled cloud sync.

**Tech Stack:** Flutter/Dart, Flutter Web, browser `performance.mark`, existing Node/Playwright tooling.

## Global Constraints

- Do not change `.env`, secrets, CI/CD, Cloudflare configuration, Supabase schema, remote data, or local IndexedDB schema/data.
- Do not add Flutter, Node, or global dependencies.
- Preserve account-switch behavior, page state, locale changes, motion settings, audio behavior, and Reduce Motion behavior.
- Use sprite Plan A: two short float cycles over about 15 seconds, then pause; play a brief blink or leaf sway about every 25 seconds while idle.
- A production release must use a unique `pubspec.yaml` version; Cloudflare steps require a separate, step-specific confirmation under `AGENTS.md`.

---

## Files and responsibilities

- `SelahFlutter/lib/web/ui/plush_companion.dart`: finite float and idle gesture scheduling.
- `SelahFlutter/lib/features/companion/plush_companion_poses.dart`: allow a resting pose to pause its animated image stream.
- `SelahFlutter/lib/design/selah_lazy_indexed_stack.dart`: keep inactive visited children at their last widget instance.
- `SelahFlutter/lib/web/ui/web_learning_app.dart`: narrow app-root rebuilds, simplify tab entrance, virtualize Notes cards, cache vocabulary spans by sentence ID and `updatedAt`.
- `SelahFlutter/lib/web/web_performance_marks.dart`: one browser-safe performance-mark helper.
- `SelahFlutter/lib/web/web_entry.dart`, `SelahFlutter/web/flutter_bootstrap.js`, `SelahFlutter/web/index.html`, `SelahFlutter/lib/web/learning_controller.dart`: mark startup phases and render the first Flutter frame before local account initialization.
- `SelahFlutter/test/plush_companion_test.dart`, `SelahFlutter/test/web_app_test.dart`, `SelahFlutter/test/web_notes_page_test.dart`, plus a focused lazy-stack test: verify finite motion, preserved page behavior, lazy card construction, and vocabulary caching.
- `SelahFlutter/pubspec.yaml`: advance the patch version and build number for the planned production release.
- `ROADMAP.md`: track the second performance round and verified outcomes.

## Task 1: Capture startup stages and show the app before account initialization

- Add `markSelahPerformance(String name)` in `web_performance_marks.dart`, calling the browser Performance API without network reporting.
- Mark HTML parsing start, entrypoint loaded, engine ready, Dart launch, before/after controller initialization, before/after local snapshot read, first Flutter frame, Today first frame, and first sync completion.
- In `web_entry.dart`, keep Supabase setup and bundled seed loading before `runApp`, but remove the awaited `controller.initialize()`. `WebLearningApp` already schedules `initialize()` after its first frame; mark the before/after boundary there.
- In `learning_controller.dart`, bracket only the first account snapshot read and first sync. Keep cloud sync scheduled after the local snapshot is applied.
- Compare five warm and five cold local Release launches. Split HTML-to-entrypoint, entrypoint-to-engine, engine-to-first-frame, and initialization-to-Today-frame durations. Defer-load admin/research/checkout code only if script parsing is proven to dominate; otherwise record that no module split is justified.

## Task 2: Stop continuous mascot animation while idle

- Replace infinite `repeat()` for `gentleFloat` and `listenPlaying` with one finite controller run. `gentleFloat` uses a 14.4-second run mapped to two 7.2-second float cycles.
- After the initial `gentleFloat` completes, schedule one 280ms blink or 1.4-second leaf sway after 25 seconds. Return to the resting pose and schedule the next gesture. Cancel timers when the cue changes, motion is disabled, the app is backgrounded, or the widget is disposed.
- Pass an animation-enabled flag to `PlushPoseImage`; disable its `TickerMode` while the controller is resting so the animated WebP does not keep advancing frames.
- Preserve cue/revision restarts, foreground handling, and motion switch behavior.

## Task 3: Limit shell rebuilds and inactive-tab updates

- Replace the `WebLearningApp` listener that rebuilds `MaterialApp` on every controller notification with a cached root configuration containing only UI locale and `motionEnabled`.
- Let `_WebRoot` listen for ordinary controller changes below `MaterialApp`, so navigation, notices, authentication, and onboarding still refresh.
- Update `SelahLazyIndexedStack` to replace the child widget only for the active tab. Inactive visited children retain their prior widget instance and state, and receive the latest widget when selected.
- Reduce `_TabEntrance` to a 100ms fade without slide/scale, only on a tab's first entry; the first-entry Listen sample reached 208ms with the original 150ms fade.

## Task 4: Virtualize Notes and cache vocabulary matching

- Convert Notes scrolling to a `CustomScrollView` with header/filter slivers and a `SliverList` whose builder creates only visible cards.
- Cache `vocabularySpans()` by sentence ID and `updatedAt`, creating results only as a card is built. Replace the entry when that sentence's timestamp changes and clear the cache on account switch.
- Keep category/search filters, expanded-card state, vocabulary selection, and scroll position unchanged.

## Task 5: Validate, record, and prepare release

- Run `flutter analyze --no-pub`, the relevant Flutter tests and full Flutter suite, existing Node/browser tests, and `flutter build web --release`.
- Run a local browser comparison using the same 21-sentence/551-event and 200-sentence/5,000-event fixtures, at 1280×800 foreground with motion enabled; collect five startup samples and idle CPU, long-task, tab-switch, first-open Notes, and cached-page rebuild measurements.
- Update the version to `1.9.2+17`, update `ROADMAP.md` only with verified results, and prepare the exact Git change set. Do not push a `codex/**` branch or merge to `main` until the required Cloudflare step has been explained and separately confirmed.

## Implementation and verification status

- [x] Implemented P0 mascot idle behavior, root rebuild isolation, inactive-tab state retention, and 100ms first-entry fade.
- [x] Implemented P1 Notes virtualization and sentence-versioned vocabulary caching, startup marks, and post-first-frame account initialization. Version is `1.9.2+17`.
- [x] `flutter analyze --no-pub` passed. Full Flutter suite: 444 passed. SelahFlutter Node tests (excluding the source-image contract that requires design files absent from this worktree): 45 passed. Supabase Node tests: 67 passed. The source-image contract was run read-only in the primary checkout: 2 passed.
- [x] Local Release build passed: app version `1.9.2`, Build ID `0d7b934be8ac63c3`. The bundle lacks public Supabase configuration, so cloud login and first-sync timing were unavailable.
- [x] Browser validation at 1280×800, foreground, motion enabled: Today idle for 60 seconds used 2.15% main-thread time; 30 seconds at 4× CPU used 1.37%. Neither interval produced a 50ms+ long task. Five first-entry runs had Event Timing medians of 80ms for Listen, 104ms for Notes, and 128ms for Settings; cached-page switches measured 48–56ms. One Notes widget test verified lazy construction with 200 sentences.
- [x] Five warm-cache reloads produced a median HTML-to-Today-first-frame time of about 888ms. Measured stage medians: HTML-to-`main.dart.js` loaded 516ms; script-loaded-to-engine-ready 80ms; engine-ready-to-Dart-main 3ms; Dart-main-to-`runApp` 25ms; `runApp`-to-first-Flutter-frame 56ms; initialization 252ms, including a 130ms local snapshot read.
- [ ] The browser navigation timings used three local seed sentences and no cloud account. The planned 21-sentence/551-event and 200-sentence/5,000-event browser fixtures, five cold starts, and production member-session comparison remain pending; do not treat the local timings as production Core Web Vitals.
- [ ] Merge/push to `main` and the resulting Cloudflare Pages production deployment require the step-specific confirmation described in `AGENTS.md`.

## Baseline and acceptance targets

Baseline: v1.9.1 member-session measurements at 1280×800 showed Today idle busy time of 54–62%, about 99% at 4× CPU with 98–158ms longest tasks, warm tab switches of 144–240ms, and first opens of Listen/Notes/Settings at 304/504/352ms. Warm startup samples ranged from 4.0–21.1 seconds and are noisy; the five-stage breakdown is not yet available.

- Today idle CPU: at most 5%; 60-second average including scheduled sprite gestures: at most 15%.
- Today at 4× CPU: at most 30% busy, with no task over 100ms.
- Warm tab switch: at most 100ms; first open of Listen, Notes, and Settings: at most 200/300/200ms.
- Notes first open with 200 sentences: at most 300ms.
- Startup: report five-run medians and each stage; set any further target only after the breakdown.
