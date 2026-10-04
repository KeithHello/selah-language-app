# Loop Listening Preparation Performance Implementation Plan

> **For agentic workers:** Implement this plan task by task with review checkpoints. The approved request authorizes implementation, local verification, a local commit, and preparation for GitHub publication.

**Goal:** Make cached loop audio ready before the user presses Start, and begin missing audio preparation as soon as the loop listening view is entered.

**Architecture:** Add a bounded batch SHA-256 bridge action and use one account-scoped Cache API key listing to identify already cached tracks. After account data loads, run a silent cache-only preflight; after loop mode is entered, run the existing preparation pipeline in the background and let Start join that same in-flight operation. Full bilingual readiness remains required before playback.

**Tech Stack:** Flutter/Dart Web, the existing JavaScript browser bridge, Cache API, Flutter tests, Node.js bridge tests.

## Global Constraints

- Do not add dependencies or change Supabase, Edge Functions, CI, secrets, or remote configuration.
- Startup preflight must not download audio or call cloud functions.
- Foreground preparation must keep existing account, registration, entitlement, quota, and failure handling.
- Do not start playback automatically; the user still presses Start.
- Update the existing design addendum before implementation and update `ROADMAP.md` only after verified work.
- Feature release version is `1.6.0+10`, following the project version policy.

---

### Task 1: Batch content hashing in the browser bridge

**Files:**
- Modify: `SelahFlutter/web/selah_bridge.js`
- Test: `SelahFlutter/test/browser_bridge.test.mjs`

- [x] Add a Node test that submits several strings to `contentHashes`, then verifies order, equality with the existing single-text hash action, and rejection of a malformed list.
- [x] Run `node --test test/browser_bridge.test.mjs` from `SelahFlutter` and confirm the new test fails because the action is not implemented.
- [x] Add `contentHashes` with an input limit of 512 strings per call, strict string validation, and the existing SHA-256 helper.
- [x] Re-run the same Node test and require all cases to pass.

### Task 2: Reuse batch hashes and cache-key inventory for loop preparation

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Modify: `SelahFlutter/test/web_loop_controller_test.dart`

- [x] Extend `_LoopPlatform` with `contentHashes` and account-scoped `audioCacheKeys`, plus action counters.
- [x] Add a failing controller test with a complete cached bilingual loop; assert that one batch hash action and one cache inventory action are enough, and that per-track `audioCached` and `audioEnsure` calls are skipped.
- [x] Implement text-hash memoization scoped to the current account lifecycle and chunk distinct texts into batches of at most 512.
- [x] Build loop track references from the batch result; reconcile verified keys against the current account cache listing and retain per-track checks when the listing is unavailable.
- [x] Run the targeted loop controller test and the full `web_loop_controller_test.dart` suite.

### Task 3: Silent startup preflight and background preparation on loop entry

**Files:**
- Modify: `SelahFlutter/lib/web/learning_controller.dart`
- Modify: `SelahFlutter/test/web_loop_controller_test.dart`

- [x] Add failing tests for (a) cached queue startup preflight completing without cloud calls, downloads, notices, or the generic busy lock; (b) missing queue preparation beginning after loop mode entry while `setListenLoopMode(true)` returns without waiting; and (c) Start joining the existing preparation.
- [x] Run those controller tests and confirm each fails for the missing behavior.
- [x] Add a cache-only warmup after account data is restored; only mark the queue ready when every desired track is present.
- [x] Start the existing preparation pipeline asynchronously after loop mode changes to true. Keep `busy` free, expose existing loop progress, surface foreground failures while the loop view is active, and preserve Start's fallback path.
- [x] Add a single-flight preparation future, clear it safely on account changes, and ensure stale account work cannot overwrite current readiness.
- [x] Re-run targeted loop tests, `web_loop_seed_audio_test.dart`, and `web_app_test.dart`.

### Task 4: Document, version, verify, and prepare release

**Files:**
- Modify: `SelahFlutter/pubspec.yaml`
- Modify: `ROADMAP.md`
- Modify: `docs/superpowers/specs/2026-10-01-listen-mode-consistency-design.md`
- Create: `docs/superpowers/plans/2026-10-04-loop-preparation-performance-plan.md`

- [x] Set the feature version to `1.6.0+10`.
- [x] Run `flutter analyze --no-pub`, `flutter test --no-pub`, the browser bridge Node tests, and `tool/web.ps1 -Action build`.
- [x] Update `ROADMAP.md` with only verified implementation and local build/test results; record production publication as pending until CI and online checks actually finish.
- [x] Review the final diff, stage only the feature files, and create the Chinese `feat:` commit `3fa8547`.
- [ ] Before any GitHub push that triggers Cloudflare Pages production deployment, report the exact target project, resulting production flow, affected configuration, risks, and cross-project impact, then wait for the required step confirmation.
