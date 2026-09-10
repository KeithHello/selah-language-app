# Selah Web UX Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成已确认的 Web 交互、输入保护、播放导航、练习／笔记操作、同步反馈和可访问性改善。

**Architecture:** 在现有 Flutter Web 分层内增量改造：纯状态与文案规则放入 `lib/web/domain/`，账户、保存、同步和播放时序放入 `learning_controller.dart`，页面行为集中在 `lib/web/ui/`。Supabase 仍使用现有表、RLS 和 Edge Functions；未提交输入只保存在本机 IndexedDB 快照，不进入云端同步。

**Tech Stack:** Flutter／Dart、现有 Supabase SDK、浏览器 IndexedDB／Cache API／MediaRecorder、Flutter widget tests、Node 浏览器桥测试。

## Global Constraints

- 不新增 Flutter 包或全局依赖。
- 不修改 Supabase schema、RLS、`.env`、密钥、CI 配置，不执行公开部署。
- Web 产品代码不得导入 `lib/app/` Fixture 或原生 SQLite。
- 未提交输入、原始录音和 UI 临时状态不上传 Supabase。
- 产品运行路径不得静默使用 Mock；Mock 只存在于测试。
- 保留暖米色、珊瑚色品牌、五底部入口、桌面侧栏和已授权角色素材接口。
- 高频触控目标按 44—48 逻辑像素设计；普通功能文字满足 4.5∶1 对比度。
- 每个行为先写失败测试，再做最小实现，最后运行对应测试。

---

## File Map

- Modify `SelahFlutter/lib/web/domain/learning_models.dart`：本机输入草稿字段、旧备份兼容。
- Create `SelahFlutter/lib/web/domain/web_status.dart`：同步状态、成长进度和输入草稿纯逻辑。
- Modify `SelahFlutter/lib/web/learning_controller.dart`：草稿保存、同步状态、播放目标、评分暂存与账户隔离。
- Modify `SelahFlutter/lib/web/ui/web_learning_app.dart`：页面操作、手机详情导航、迷你播放器、表单和可访问性。
- Modify tests under `SelahFlutter/test/`：控制器、模型、组件和浏览器行为回归。
- Modify `ROADMAP.md` and create acceptance notes only after verified implementation.

### Task 1: Local input drafts and honest sync state

**Interfaces:**
- Produces `LearningSnapshot.todayInput` (`String`) and `LearningSnapshot.segmentInputs` (`List<String>`), included in local backup JSON but ignored by cloud table mapping.
- Produces `WebSyncStatus` / `WebSyncPresentation` in `web_status.dart` with values `localOnly`, `savingLocal`, `localSaveFailed`, `syncing`, `syncFailed`, `pendingChanges`, `synced`, `offline`.
- Produces `LearningController.updateTodayInput(String text)` and `LearningController.clearTodayInput()`.

- [ ] Add model tests for old backups without new fields, draft persistence through copy／import, and drafts surviving account-scoped reload.
- [ ] Add controller tests proving input changes are debounced and saved locally, save failure is exposed, and successful local save never sets cloud sync success.
- [ ] Add pure status tests for unconfigured, guest, offline, syncing, failed, pending, and last-success states.
- [ ] Implement model fields and status helper.
- [ ] Wire controller autosave and state flags.
- [ ] Run `flutter test test/web_models_test.dart test/web_controller_test.dart` and verify green.

### Task 2: Generation and recording safety

**Interfaces:**
- Consumes `LearningController.todayInput` and generation request version.
- Produces transcript application actions: insert at cursor, explicit replace-all, retry, discard.
- Recording cancellation and pending-recording failure remain controller-owned.

- [ ] Add controller／widget tests proving edits during generation survive success and failure.
- [ ] Add tests proving transcript insertion does not replace existing text, while explicit replace does.
- [ ] Add tests proving overlong transcript shows an editable error rather than silent truncation.
- [ ] Implement request-version clearing and transcript actions in Today page.
- [ ] Add visible cancel recording, retry, discard, and refresh-loss warning for pending transcription.
- [ ] Run focused Flutter tests and manual local browser input flow.

### Task 3: Mobile detail navigation and persistent playback controls

**Interfaces:**
- Produces controller playback target separate from selected sentence.
- Produces in-app hash navigation for sentence detail: `#/listen/<sentenceId>` and `#/notes/<sentenceId>`.
- Produces a mini-player widget with play／pause, open detail, and close actions.

- [ ] Add controller tests for selected vs playing sentence, cross-page stop／pause, and one-time completion.
- [ ] Add widget tests at 390px for list → detail → browser/back, filter／scroll state preservation, and no horizontal overflow.
- [ ] Add desktop tests at 1280px preserving split layout.
- [ ] Implement navigation and mini-player without a new router package.
- [ ] Make “去聆听这句” open the listen detail and start playback only from user activation.
- [ ] Run focused widget tests and browser viewport checks.

### Task 4: Practice, notes, onboarding, and settings operations

**Interfaces:**
- Produces pending practice rating state in controller, with commit only after explicit next／complete.
- Produces notes filter state including category and mastery, copyable text, and clear-filter action.
- Reuses existing Supabase Auth methods for sign-in, sign-up, and password recovery; no auth config changes.

- [ ] Add tests for empty practice, free practice, skip, pending rating undo, save failure retry, and no event before commit.
- [ ] Add tests for notes no-content vs no-filter-results and non-decorative filter control.
- [ ] Add widget tests for password visibility, inline validation, and auth cancellation preserving input.
- [ ] Add onboarding tests for default companion name, recommended audio seeds, login-return path, and selected-vs-preview behavior.
- [ ] Implement the smallest UI and controller changes to satisfy those tests.
- [ ] Run focused Flutter tests.

### Task 5: Visual accessibility, growth progress, and full regression

**Interfaces:**
- Produces shared growth progress values from `LearningEngine.stage` and session count.
- Web typography and functional colors remain token-based.

- [ ] Add tests for stage boundaries 0／4／5／14／15／29／30／31 and final-stage non-resetting progress.
- [ ] Add widget tests for 200％ text scale, keyboard focus, semantic labels, and reduced motion availability.
- [ ] Adjust Web-scoped font sizes, functional colors, hit areas, and growth display without changing native client behavior.
- [ ] Run `flutter analyze --no-pub`, full `flutter test`, `node --test test/browser_bridge.test.mjs`, and `powershell -NoProfile -File tool/web.ps1 -Action build` from `SelahFlutter/`.
- [ ] Run isolated local browser acceptance at 320／390／768／1280／1440 widths.
- [ ] Run real Supabase smoke with a dedicated test account only if service functions are available; record any missing deployment separately.
- [ ] Update `ROADMAP.md` and write acceptance evidence with exact command results and remaining external blockers.

## Self-Review

- Every spec section maps to Tasks 1—5; external deployment and schema work remain explicitly out of scope.
- No task requires a new dependency or cloud migration.
- Cloud and local draft states have separate interfaces, preventing local autosave from being reported as cloud sync.
- Practice undo is limited to uncommitted ratings, preserving append-only cloud events.
- Navigation uses existing Flutter navigation and hash strings, avoiding server route rewrite requirements.
