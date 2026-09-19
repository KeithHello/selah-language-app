# Azure Native Seed Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task with verification checkpoints.

**Goal:** Replace the ten bundled Traditional Chinese source tracks with Azure Speech Taiwan Mandarin audio and make the result locally auditable in the Web loop-listening preview.

**Architecture:** A local Python generator reads `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` from the existing ignored `.env`, calls the Azure Speech REST endpoint with SSML voice `zh-TW-HsiaoChenNeural`, and writes only the ten source MP3s. The existing local packaging script recalculates `seed-audio.json`; no Supabase schema, Edge Function, frontend routing, or public deployment changes are made in this phase.

**Tech Stack:** Python 3 standard library (`urllib`, `json`, `hashlib`, `xml.sax.saxutils`), Azure Speech REST API, Flutter Web Release build, existing local audio manifest and loop-listening tests.

## Global Constraints

- Never print, commit, or embed `AZURE_SPEECH_KEY` or any Supabase secret.
- Use only the existing local `.env`; do not edit `.env` or add dependencies.
- Generate exactly the ten `seed-xxx-source-zh-Hant.mp3` files already present in the starter set.
- Keep the current 16 kHz mono MP3 output contract and update SHA-256 and byte size in `SelahFlutter/assets/content/seed-audio.json`.
- Do not deploy Supabase functions, change database schema, alter Cloudflare, push Git, or publish a public site in this phase.
- Preserve the existing English and Japanese assets and all unrelated untracked files.

---

### Task 1: Add a tested Azure seed-audio generator

**Files:**
- Create: `supabase/scripts/generate_azure_seed_audio.py`
- Create: `supabase/tests/azure_seed_audio_script_test.py`

**Interfaces:**
- `build_ssml(text: str, voice: str = "zh-TW-HsiaoChenNeural") -> str`
- `voice_output_path(seed_id: str, audio_dir: Path) -> Path`
- `load_local_env(path: Path) -> dict[str, str]`
- `generate_seed_audio(seed_path: Path, audio_dir: Path, env_path: Path, voice: str, dry_run: bool) -> int`

- [x] **Step 1: Write unit tests first**

  Cover XML escaping, fixed Taiwan voice, exact ten source filenames, missing credential failure, dry-run no-write behavior, and MP3 response validation without making a network call.

- [x] **Step 2: Run the focused test before implementation**

  Run: `python -m unittest supabase/tests/azure_seed_audio_script_test.py`

  Expected: FAIL because `supabase/scripts/generate_azure_seed_audio.py` does not exist yet.

- [x] **Step 3: Implement the minimal script**

  Read only `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`; build `https://{region}.tts.speech.microsoft.com/cognitiveservices/v1`; send `application/ssml+xml` with `audio-16khz-128kbitrate-mono-mp3`; write each response atomically through a temporary sibling file; validate `ID3` or MPEG frame bytes; never include credentials in errors.

- [x] **Step 4: Run focused tests again**

  Run: `python -m unittest supabase/tests/azure_seed_audio_script_test.py`

  Expected: all tests pass.

- [ ] **Step 5: Commit the local implementation only after later asset verification**

  The commit is deferred until Task 4 so the generated asset evidence and roadmap entry are included together.

### Task 2: Generate and package the ten Taiwan Mandarin tracks

**Files:**
- Modify: `SelahFlutter/assets/audio/seed-001-source-zh-Hant.mp3` through the ten existing source files
- Modify: `SelahFlutter/assets/content/seed-audio.json`

- [x] **Step 1: Run a dry run and verify the planned ten IDs**

  Run: `python supabase/scripts/generate_azure_seed_audio.py --dry-run`

  Expected: ten seed IDs and output paths, with no file writes.

- [ ] **Step 2: Generate the ten MP3s using Azure** — blocked by HTTP 401 from Azure Speech; no target file was overwritten.

  Run: `python supabase/scripts/generate_azure_seed_audio.py`

  Expected: ten HTTP 200 responses, ten valid MP3 files, no secret values in output.

- [ ] **Step 3: Rebuild the local manifest** — waiting for successful Azure generation.

  Run: `python SelahFlutter/tool/package_seed_audio.py --local`

  Expected: the manifest still has 60 entries, including ten `:source:zh-Hant` entries and ten `:source:ja` entries.

- [ ] **Step 4: Verify all generated files and hashes** — waiting for successful Azure generation.

  Run: `python -m unittest SelahFlutter/test/seed_audio_packager_test.py` and `python -m unittest supabase/tests/azure_seed_audio_script_test.py`

  Expected: both focused suites pass; every generated file is MP3 and the manifest hash/size matches.

### Task 3: Build and open the local preview

**Files:**
- Modify: `SelahFlutter/build/web/` as generated output only; do not stage it unless the existing repository workflow requires it.

- [x] **Step 1: Build the Web release**

  Run: `./SelahFlutter/tool/web.ps1 -Action build`

  Expected: exit code 0, Supabase public config bundled, new Build ID printed.

- [x] **Step 2: Validate the built manifest and representative audio** — the package has 10 sentences, 60 manifest entries, 10 Chinese native entries, 189 precache assets, and a representative `audio/mpeg` response; the representative Chinese file is still the pre-existing asset because Azure generation was blocked.

  Run a local Python check against `SelahFlutter/build/web/assets/assets/content/seed-sentences.json`, `seed-audio.json`, and one `seed-001-source-zh-Hant.mp3`.

  Expected: 10 sentences, 60 audio entries, 10 Chinese native entries, 189 precache entries, MP3 content starts with an ID3 or MPEG frame.

- [x] **Step 3: Start the local release server**

  Run: `node SelahFlutter/tool/serve_release.js 5191`

  Expected: `http://127.0.0.1:5191/` serves the freshly built app.

- [x] **Step 4: Browser confirmation** — the local Listen page loaded and a bundled 4-second track reached the end of playback; subjective Azure sound confirmation remains pending.

  Open the local URL, keep the onboarding state unchanged, and verify the app loads without a Flutter error. The actual audio comparison is made from the Listen/loop panel after selecting starter sentences; do not modify account data or submit forms during this check.

### Task 4: Record verified status and next plan

**Files:**
- Modify: `ROADMAP.md`
- Create: `docs/azure-native-audio-acceptance-2026-09-19.md`

- [x] **Step 1: Record evidence** — see `docs/azure-native-audio-acceptance-2026-09-19.md`; it explicitly records the Azure 401 blocker and does not claim new-audio acceptance.

  Record generated voice, model endpoint, ten-file count, manifest count, focused tests, build ID, and local preview URL. Do not claim the sound is “native” until the owner listens and confirms.

- [x] **Step 2: Record the next Edge Function plan**

  Keep online routing as a separate follow-up: pass source language and provider metadata through the audio contract, route `zh-Hant`/`zh-Hans` to Azure, retain OpenAI for English, add provider-specific cache hashes and mocked failure tests, then deploy only `audio-generate` after explicit remote deployment approval.

- [x] **Step 3: Record English accent decision**

  Recommend an explicit `en-US` default for broad learner comprehensibility, add `en-GB` only as an optional voice profile after measuring demand, and keep accent as a voice-profile dimension so caches and user preferences remain stable.
