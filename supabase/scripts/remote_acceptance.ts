#!/usr/bin/env -S deno run --allow-net --allow-env --allow-read
/**
 * Selah remote acceptance runner.
 *
 * The default mode is dry-run and performs no network or file I/O. The
 * execute mode is intentionally billable: it signs in with an ordinary test
 * account JWT and uses a recording supplied by the caller. One provider
 * attempt is allowed for each of transcription, single-sentence generation,
 * capture preparation, a batch of at most five segments, and TTS. Replays
 * prove idempotence and must not create another provider attempt.
 *
 * Required only for --execute:
 *   SUPABASE_URL
 *   SUPABASE_PUBLISHABLE_KEY
 *   SUPABASE_TEST_EMAIL
 *   SUPABASE_TEST_PASSWORD
 *   REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true
 *   REMOTE_ACCEPTANCE_AUDIO_FILE (or --audio-file)
 *
 * Usage:
 *   deno run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts
 *   deno run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts \
 *     --execute --audio-file fixtures/capture.wav
 *   deno run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts \
 *     --execute --resume <run-id> --audio-file fixtures/capture.wav
 */

import {
  MAX_SPEECH_DURATION_MS,
  MAX_SPEECH_FILE_BYTES,
} from "../functions/_shared/speech_contract.ts";

const DEFAULT_AUDIO_DURATION_MS = 2_500;
const MAX_BATCH_SEGMENTS = 5;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Provider attempts permitted by one acceptance run. */
export const ACCEPTANCE_PROVIDER_CALL_BUDGET = Object.freeze({
  speechTranscription: 1,
  sentenceGeneration: 1,
  capturePreparation: 1,
  batchGeneration: 1,
  tts: 1,
});

export interface RemoteAcceptanceConfig {
  supabaseURL: string;
  publishableKey: string;
  email: string;
  password: string;
  secondaryEmail?: string;
  secondaryPassword?: string;
  audioFilePath?: string;
  audioDurationMs?: number;
  rlsSentenceId?: string;
  rlsEventId?: string;
}

export interface RemoteAcceptanceOptions {
  execute: boolean;
  help: boolean;
  resumeRunId?: string;
  audioFilePath?: string;
  audioDurationMs?: number;
}

export interface AcceptanceRunPlan {
  runId: string;
  sentenceId: string;
  requestIds: {
    speechTranscription: string;
    sentenceGeneration: string;
    capturePreparation: string;
    batchGeneration: string;
    audioGeneration: string;
  };
}

export interface RemoteAcceptanceRunOptions {
  runId?: string;
  audioFile?: File;
  audioDurationMs?: number;
}

export interface RemoteAcceptanceCommandDependencies {
  fetch?: FetchLike;
  readAudioFile?: (path: string) => Promise<Uint8Array>;
}

export function parseOptions(args: string[]): RemoteAcceptanceOptions {
  const options: RemoteAcceptanceOptions = { execute: false, help: false };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--execute") {
      options.execute = true;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      options.help = true;
      continue;
    }

    const separator = arg.indexOf("=");
    const flag = separator < 0 ? arg : arg.slice(0, separator);
    const inlineValue = separator < 0 ? undefined : arg.slice(separator + 1);
    if (
      flag === "--resume" || flag === "--resume-run" ||
      flag === "--resume-run-id"
    ) {
      const value = inlineValue ?? args[++index];
      if (
        !value?.trim() ||
        (inlineValue === undefined && value.trim().startsWith("--"))
      ) {
        throw new Error(`${flag} requires a run ID`);
      }
      options.resumeRunId = value.trim();
      continue;
    }
    if (flag === "--audio-file") {
      const value = inlineValue ?? args[++index];
      if (
        !value?.trim() ||
        (inlineValue === undefined && value.trim().startsWith("--"))
      ) {
        throw new Error("--audio-file requires a path");
      }
      options.audioFilePath = value.trim();
      continue;
    }
    if (flag === "--audio-duration-ms") {
      const value = inlineValue ?? args[++index];
      options.audioDurationMs = parseDuration(value, "--audio-duration-ms");
      continue;
    }
    const unknownFlag = arg.startsWith("--")
      ? arg.split("=", 1)[0]
      : "<positional>";
    throw new Error(`unknown option: ${unknownFlag}`);
  }
  return options;
}

export function loadExecuteConfig(
  environment: Record<string, string | undefined>,
): RemoteAcceptanceConfig {
  if (environment.REMOTE_ACCEPTANCE_ALLOW_BILLABLE !== "true") {
    throw new Error(
      "--execute requires REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true; no billable request was sent",
    );
  }

  const required = {
    SUPABASE_URL: environment.SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY: environment.SUPABASE_PUBLISHABLE_KEY,
    SUPABASE_TEST_EMAIL: environment.SUPABASE_TEST_EMAIL,
    SUPABASE_TEST_PASSWORD: environment.SUPABASE_TEST_PASSWORD,
  };
  const missing = Object.entries(required)
    .filter(([, value]) => !value?.trim())
    .map(([name]) => name);
  if (missing.length > 0) {
    throw new Error(`--execute is missing: ${missing.join(", ")}`);
  }

  const supabaseURL = required.SUPABASE_URL!.trim().replace(/\/$/, "");
  let parsedURL: URL;
  try {
    parsedURL = new URL(supabaseURL);
  } catch {
    throw new Error("SUPABASE_URL must be an HTTPS URL");
  }
  if (parsedURL.protocol !== "https:" || !parsedURL.host) {
    throw new Error("SUPABASE_URL must be an HTTPS URL");
  }

  const secondaryEmail = firstTrimmed(
    environment.SUPABASE_TEST_EMAIL_2,
    environment.SUPABASE_TEST_EMAIL_SECONDARY,
  );
  const secondaryPassword = firstTrimmed(
    environment.SUPABASE_TEST_PASSWORD_2,
    environment.SUPABASE_TEST_PASSWORD_SECONDARY,
  );
  if (
    (secondaryEmail && !secondaryPassword) ||
    (!secondaryEmail && secondaryPassword)
  ) {
    throw new Error(
      "secondary test account requires both SUPABASE_TEST_EMAIL_2 and SUPABASE_TEST_PASSWORD_2",
    );
  }

  const config: RemoteAcceptanceConfig = {
    supabaseURL,
    publishableKey: required.SUPABASE_PUBLISHABLE_KEY!,
    email: required.SUPABASE_TEST_EMAIL!,
    password: required.SUPABASE_TEST_PASSWORD!,
  };
  if (secondaryEmail && secondaryPassword) {
    config.secondaryEmail = secondaryEmail;
    config.secondaryPassword = secondaryPassword;
  }

  const audioFilePath = firstTrimmed(
    environment.REMOTE_ACCEPTANCE_AUDIO_FILE,
    environment.SUPABASE_TEST_AUDIO_FILE,
  );
  if (audioFilePath) config.audioFilePath = audioFilePath;

  if (environment.REMOTE_ACCEPTANCE_AUDIO_DURATION_MS?.trim()) {
    config.audioDurationMs = parseDuration(
      environment.REMOTE_ACCEPTANCE_AUDIO_DURATION_MS,
      "REMOTE_ACCEPTANCE_AUDIO_DURATION_MS",
    );
  }

  const rlsSentenceId = firstTrimmed(environment.SUPABASE_RLS_SENTENCE_ID);
  if (rlsSentenceId) {
    assertUUID(rlsSentenceId, "SUPABASE_RLS_SENTENCE_ID");
    config.rlsSentenceId = rlsSentenceId.toLowerCase();
  }
  const rlsEventId = firstTrimmed(environment.SUPABASE_RLS_EVENT_ID);
  if (rlsEventId) {
    assertUUID(rlsEventId, "SUPABASE_RLS_EVENT_ID");
    config.rlsEventId = rlsEventId.toLowerCase();
  }

  return config;
}

export function dryRunSummary(): string[] {
  return [
    "DRY RUN ONLY: no Supabase, OpenAI, Storage, or auth request will be made.",
    "Planned checks: ordinary JWT auth → config bootstrap → supplied-recording STT → single sentence → capture preparation → one batch of at most five segments → one TTS → signed URL download.",
    "Provider-attempt budget: 1 speech transcription + 1 single sentence + 1 preparation + 1 batch (≤5 segments) + 1 TTS; replay/cache checks must add zero provider attempts.",
    "A recording is read only for --execute after the billable gate; the runner never synthesizes an STT sample with TTS.",
    "Use --resume <run-id> to retry a known run with the same request IDs; a new execution gets a fresh run ID.",
    "Optional second-account and RLS fixture checks use ordinary password-authenticated JWTs. Cross-device UI and physical-device behavior remain unverified.",
  ];
}

interface AuthPayload {
  access_token?: unknown;
}

interface CaptureSegment {
  segmentId?: unknown;
  orderIndex?: unknown;
  sourceText?: unknown;
}

interface PreparationPayload {
  segments?: unknown;
}

interface BatchPayload {
  items?: unknown;
}

interface AudioPayload {
  status?: unknown;
  manifestId?: unknown;
  downloadUrl?: unknown;
  byteSize?: unknown;
  cacheHit?: unknown;
}

interface SpeechPayload {
  text?: unknown;
  language?: unknown;
  durationMs?: unknown;
}

interface RlsCheckResult {
  ordinaryJwt: true;
  ownAudioManifestVisible: true;
  secondaryAccount: "not_configured" | "isolated";
  sentenceFixture: "not_configured" | "isolated";
  eventFixture: "not_configured" | "isolated";
  crossDeviceUI: "not_verified";
}

interface RlsPreflight {
  secondaryToken: string | null;
  sentenceFixture: RlsCheckResult["sentenceFixture"];
  eventFixture: RlsCheckResult["eventFixture"];
}

type FetchLike = typeof fetch;
// Counts this runner's function/download requests. Provider attempts remain
// an explicit upper-bound budget because a replay response does not expose
// the server-side provider ledger.
type RequestCounts = Record<string, number>;

export async function runRemoteAcceptance(
  config: RemoteAcceptanceConfig,
  fetchImpl: FetchLike = fetch,
  options: RemoteAcceptanceRunOptions = {},
): Promise<Record<string, unknown>> {
  const audioFile = options.audioFile;
  if (!(audioFile instanceof File) || audioFile.size < 1) {
    throw new Error("audio sample file is required for remote acceptance");
  }
  if (audioFile.size > MAX_SPEECH_FILE_BYTES) {
    throw new Error("supplied audio sample exceeds the 10 MiB limit");
  }
  if (!extensionForMime(audioFile.type)) {
    throw new Error("supplied audio sample has an unsupported MIME type");
  }
  const audioDurationMs = options.audioDurationMs ?? DEFAULT_AUDIO_DURATION_MS;
  assertDuration(audioDurationMs, "audio duration");

  const plan = createRunPlan(options.runId);
  const requestCounts: RequestCounts = {};
  const accessToken = await signInAccount(
    { email: config.email, password: config.password },
    config,
    fetchImpl,
  );
  await assertSessionRestored(config, accessToken, fetchImpl);
  const bootstrap = await callFunction(
    config,
    accessToken,
    "config-bootstrap",
    "GET",
    undefined,
    fetchImpl,
    requestCounts,
  );
  assertBootstrap(bootstrap);

  // Reject account or existing-fixture failures before any billable endpoint.
  const rlsPreflight = await prepareRlsChecks(config, accessToken, fetchImpl);

  const transcript = await callSpeechTranscribe(
    config,
    accessToken,
    audioFile,
    audioDurationMs,
    plan.requestIds.speechTranscription,
    fetchImpl,
    requestCounts,
  );
  const transcriptReplay = await callSpeechTranscribe(
    config,
    accessToken,
    audioFile,
    audioDurationMs,
    plan.requestIds.speechTranscription,
    fetchImpl,
    requestCounts,
  );
  assertSpeechPayload(transcript);
  assertSpeechPayload(transcriptReplay);
  assertSamePayload(
    transcript,
    transcriptReplay,
    "speech transcription replay",
  );
  const sourceText = String(transcript.text).trim();
  if (sourceText.length > 500) {
    throw new Error(
      "transcription exceeds the single-sentence acceptance input limit",
    );
  }

  const sentenceBody = {
    sourceText,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    clientRequestId: plan.requestIds.sentenceGeneration,
  };
  const sentence = await callFunction(
    config,
    accessToken,
    "sentences-generate",
    "POST",
    sentenceBody,
    fetchImpl,
    requestCounts,
  ) as Record<string, unknown>;
  const sentenceReplay = await callFunction(
    config,
    accessToken,
    "sentences-generate",
    "POST",
    sentenceBody,
    fetchImpl,
    requestCounts,
  ) as Record<string, unknown>;
  assertSamePayload(sentence, sentenceReplay, "sentence generation replay");

  const preparationBody = {
    rawTranscript: sourceText,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    clientRequestId: plan.requestIds.capturePreparation,
  };
  const preparation = await callFunction(
    config,
    accessToken,
    "sentences-prepare",
    "POST",
    preparationBody,
    fetchImpl,
    requestCounts,
  ) as PreparationPayload;
  const preparationReplay = await callFunction(
    config,
    accessToken,
    "sentences-prepare",
    "POST",
    preparationBody,
    fetchImpl,
    requestCounts,
  ) as PreparationPayload;
  assertSamePayload(
    preparation,
    preparationReplay,
    "capture preparation replay",
  );

  if (
    Array.isArray(preparation.segments) &&
    preparation.segments.length > MAX_BATCH_SEGMENTS
  ) {
    throw new Error(
      "capture preparation returned more than five segments; bounded acceptance stopped",
    );
  }
  const segments = normalizeSegments(preparation.segments);
  if (segments.length === 0) {
    throw new Error("capture preparation returned no usable segments");
  }
  const batchBody = {
    clientRequestId: plan.requestIds.batchGeneration,
    segments,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
  };
  const batch = await callFunction(
    config,
    accessToken,
    "sentences-batch-generate",
    "POST",
    batchBody,
    fetchImpl,
    requestCounts,
  ) as BatchPayload;
  const batchReplay = await callFunction(
    config,
    accessToken,
    "sentences-batch-generate",
    "POST",
    batchBody,
    fetchImpl,
    requestCounts,
  ) as BatchPayload;
  assertSamePayload(batch, batchReplay, "batch translation replay");
  const items = Array.isArray(batch.items) ? batch.items : [];
  if (items.length !== segments.length) {
    throw new Error("batch translation item count does not match segments");
  }
  const targetText = firstTargetText(items);

  const audio = await callFunction(
    config,
    accessToken,
    "audio-generate",
    "POST",
    {
      sentenceId: plan.sentenceId,
      targetText,
      voiceProfile: "gentle-natural",
      reason: "remote_acceptance",
      clientRequestId: plan.requestIds.audioGeneration,
    },
    fetchImpl,
    requestCounts,
  ) as AudioPayload;
  assertAudio(audio);

  const audioReplay = await callFunction(
    config,
    accessToken,
    "audio-generate",
    "POST",
    {
      sentenceId: plan.sentenceId,
      targetText,
      voiceProfile: "gentle-natural",
      reason: "remote_acceptance",
      clientRequestId: plan.requestIds.audioGeneration,
    },
    fetchImpl,
    requestCounts,
  ) as AudioPayload;
  assertAudio(audioReplay);
  assertCacheHit(audioReplay, "audio generation replay");
  assertSameAudioIdentity(audio, audioReplay);

  const refreshedAudio = await callFunction(
    config,
    accessToken,
    "audio-download-url",
    "POST",
    { manifestId: audio.manifestId },
    fetchImpl,
    requestCounts,
  ) as AudioPayload;
  assertAudio(refreshedAudio);
  assertCacheHit(refreshedAudio, "signed URL refresh");

  incrementCount(requestCounts, "audio-download");
  const audioResponse = await fetchImpl(String(refreshedAudio.downloadUrl));
  if (!audioResponse.ok) {
    throw new Error(
      `signed audio download failed with HTTP ${audioResponse.status}`,
    );
  }
  const audioBytes = new Uint8Array(await audioResponse.arrayBuffer());
  if (audioBytes.byteLength < 512) {
    throw new Error("signed audio download is unexpectedly small");
  }

  const rls = await runRlsChecks(
    config,
    accessToken,
    String(audio.manifestId),
    fetchImpl,
    rlsPreflight,
  );
  assertRequestBounds(requestCounts);

  return {
    status: "passed",
    checks: [
      "auth-ordinary-jwt",
      "auth-session-restore",
      "config-bootstrap",
      "speech-transcription",
      "speech-transcription-replay",
      "sentence-generation",
      "sentence-generation-replay",
      "capture-preparation",
      "capture-preparation-replay",
      "batch-translation",
      "batch-translation-replay",
      "tts-generation",
      "tts-generation-replay",
      "signed-url-refresh",
      "audio-download",
      "rls-own-audio-manifest",
    ],
    runId: plan.runId,
    segmentCount: segments.length,
    batchSegmentLimit: MAX_BATCH_SEGMENTS,
    requestCounts,
    providerCallBudget: ACCEPTANCE_PROVIDER_CALL_BUDGET,
    providerCallUpperBound: ACCEPTANCE_PROVIDER_CALL_BUDGET,
    audioBytes: audioBytes.byteLength,
    audioCacheHitOnReplay: audioReplay.cacheHit === true,
    rls,
    unverified: [
      "provider usage ledger actual-attempt count",
      "practice UI save",
      "notes UI persistence",
      "cross-device UI and physical-device behavior",
    ],
  };
}

/** Build stable IDs for one run. Passing the same run ID is the resume path. */
export function createRunPlan(runId = createRunId()): AcceptanceRunPlan {
  const normalizedRunId = runId.trim();
  if (!normalizedRunId) throw new Error("run ID must not be empty");
  return {
    runId: normalizedRunId,
    sentenceId: stableUUID(`${normalizedRunId}:sentence`),
    requestIds: {
      speechTranscription: stableUUID(
        `${normalizedRunId}:speech-transcription`,
      ),
      sentenceGeneration: stableUUID(`${normalizedRunId}:sentence-generation`),
      capturePreparation: stableUUID(`${normalizedRunId}:capture-preparation`),
      batchGeneration: stableUUID(`${normalizedRunId}:batch-generation`),
      audioGeneration: stableUUID(`${normalizedRunId}:audio-generation`),
    },
  };
}

/** Run CLI policy without printing or performing side effects. */
export async function runRemoteAcceptanceCommand(
  args: string[],
  environment: Record<string, string | undefined> = {},
  dependencies: RemoteAcceptanceCommandDependencies = {},
): Promise<Record<string, unknown>> {
  const options = parseOptions(args);
  if (options.help) {
    return { status: "help", lines: usageLines() };
  }
  if (!options.execute) {
    return { status: "dry-run", lines: dryRunSummary() };
  }

  // loadExecuteConfig checks the billable gate before reading the recording.
  const config = loadExecuteConfig(environment);
  const audioFilePath = options.audioFilePath ?? config.audioFilePath;
  if (!audioFilePath) {
    throw new Error(
      "--execute requires a supplied audio sample via --audio-file or REMOTE_ACCEPTANCE_AUDIO_FILE",
    );
  }
  const readAudioFile = dependencies.readAudioFile ??
    ((path: string) => Deno.readFile(path));
  const audioFile = await readAudioSample(audioFilePath, readAudioFile);
  const audioDurationMs = options.audioDurationMs ?? config.audioDurationMs ??
    DEFAULT_AUDIO_DURATION_MS;
  const fetchImpl = dependencies.fetch ?? fetch;
  const runId = options.resumeRunId ?? createRunId();
  try {
    return await runRemoteAcceptance(config, fetchImpl, {
      runId,
      audioFile,
      audioDurationMs,
    });
  } catch (error) {
    const detail = error instanceof Error
      ? error.message
      : "remote acceptance failed";
    throw new Error(
      `remote acceptance run ${runId} failed; retry with --resume ${runId}: ${detail}`,
    );
  }
}

async function signInAccount(
  account: { email: string; password: string },
  config: RemoteAcceptanceConfig,
  fetchImpl: FetchLike,
): Promise<string> {
  const response = await fetchImpl(
    `${config.supabaseURL}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: config.publishableKey,
      },
      body: JSON.stringify({
        email: account.email,
        password: account.password,
      }),
    },
  );
  const payload = await readJSON(response);
  if (
    !response.ok || typeof (payload as AuthPayload).access_token !== "string"
  ) {
    throw new Error(`test account sign-in failed with HTTP ${response.status}`);
  }
  return (payload as AuthPayload).access_token as string;
}

async function assertSessionRestored(
  config: RemoteAcceptanceConfig,
  accessToken: string,
  fetchImpl: FetchLike,
): Promise<void> {
  const response = await fetchImpl(`${config.supabaseURL}/auth/v1/user`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: config.publishableKey,
    },
  });
  const payload = await readJSON(response);
  if (
    !response.ok || !payload || typeof payload !== "object" ||
    typeof (payload as Record<string, unknown>).id !== "string"
  ) {
    throw new Error(
      `test account session restore failed with HTTP ${response.status}`,
    );
  }
}

async function callFunction(
  config: RemoteAcceptanceConfig,
  accessToken: string,
  functionName: string,
  method: "GET" | "POST",
  body: unknown,
  fetchImpl: FetchLike,
  requestCounts?: RequestCounts,
): Promise<unknown> {
  if (requestCounts) incrementCount(requestCounts, functionName);
  const response = await fetchImpl(
    `${config.supabaseURL}/functions/v1/${functionName}`,
    {
      method,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: config.publishableKey,
        ...(method === "POST" ? { "Content-Type": "application/json" } : {}),
      },
      ...(method === "POST" ? { body: JSON.stringify(body) } : {}),
    },
  );
  const payload = await readJSON(response);
  if (!response.ok) {
    const code = safeErrorCode(payload);
    throw new Error(
      `${functionName} failed with HTTP ${response.status}: ${code}`,
    );
  }
  return payload;
}

async function readJSON(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    throw new Error(
      `endpoint returned invalid JSON with HTTP ${response.status}`,
    );
  }
}

function assertBootstrap(value: unknown): void {
  if (!value || typeof value !== "object") {
    throw new Error("config-bootstrap returned an invalid payload");
  }
  const payload = value as Record<string, unknown>;
  if (payload.defaultVoiceProfile !== "gentle-natural") {
    throw new Error("config-bootstrap returned an unexpected default voice");
  }
  if (
    !Array.isArray(payload.voiceProfiles) || payload.voiceProfiles.length !== 4
  ) {
    throw new Error("config-bootstrap did not return four voice profiles");
  }
}

function normalizeSegments(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  return value.flatMap((item, index) => {
    if (!item || typeof item !== "object") return [];
    const candidate = item as CaptureSegment;
    if (
      typeof candidate.segmentId !== "string" ||
      !UUID_PATTERN.test(candidate.segmentId) ||
      typeof candidate.sourceText !== "string" ||
      !candidate.sourceText.trim()
    ) return [];
    const segmentId = candidate.segmentId.toLowerCase();
    if (seen.has(segmentId)) {
      throw new Error("capture preparation returned duplicate segment IDs");
    }
    seen.add(segmentId);
    return [{
      segmentId,
      orderIndex: typeof candidate.orderIndex === "number"
        ? candidate.orderIndex
        : index,
      sourceText: candidate.sourceText.trim(),
    }];
  });
}

function firstTargetText(items: unknown[]): string {
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const targetText = (item as Record<string, unknown>).targetText;
    if (typeof targetText === "string" && targetText.trim()) {
      return targetText.trim();
    }
  }
  throw new Error("batch translation returned no target text");
}

function assertAudio(value: unknown): asserts value is AudioPayload {
  if (!value || typeof value !== "object") {
    throw new Error("audio endpoint returned an invalid payload");
  }
  const payload = value as AudioPayload;
  if (
    payload.status !== "ready" ||
    typeof payload.manifestId !== "string" ||
    typeof payload.downloadUrl !== "string" ||
    !payload.downloadUrl.startsWith("http")
  ) {
    throw new Error("audio endpoint did not return a ready signed URL");
  }
}

function assertSamePayload(
  first: unknown,
  second: unknown,
  label: string,
): void {
  if (JSON.stringify(first) !== JSON.stringify(second)) {
    throw new Error(`${label} returned different payloads`);
  }
}

async function callSpeechTranscribe(
  config: RemoteAcceptanceConfig,
  accessToken: string,
  audioFile: File,
  durationMs: number,
  clientRequestId: string,
  fetchImpl: FetchLike,
  requestCounts: RequestCounts,
): Promise<SpeechPayload> {
  incrementCount(requestCounts, "speech-transcribe");
  const extension = extensionForMime(audioFile.type);
  if (!extension) {
    throw new Error("supplied audio sample has an unsupported MIME type");
  }
  const form = new FormData();
  form.append("file", audioFile, `acceptance.${extension}`);
  form.set("clientRequestId", clientRequestId);
  form.set("language", "zh-Hant");
  form.set("durationMs", String(durationMs));
  const response = await fetchImpl(
    `${config.supabaseURL}/functions/v1/speech-transcribe`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: config.publishableKey,
      },
      // Do not set Content-Type: fetch adds the multipart boundary.
      body: form,
    },
  );
  const payload = await readJSON(response);
  if (!response.ok) throwFunctionError("speech-transcribe", response, payload);
  return payload as SpeechPayload;
}

function assertSpeechPayload(value: SpeechPayload): void {
  if (typeof value.text !== "string" || !value.text.trim()) {
    throw new Error("speech-transcribe returned no usable text");
  }
}

function assertSameAudioIdentity(
  first: AudioPayload,
  second: AudioPayload,
): void {
  if (
    first.status !== second.status || first.manifestId !== second.manifestId
  ) {
    throw new Error("audio generation replay returned a different manifest");
  }
}

function assertCacheHit(value: AudioPayload, label: string): void {
  if (value.cacheHit !== true) {
    throw new Error(`${label} did not report a cache hit`);
  }
}

async function readRlsRows(
  config: RemoteAcceptanceConfig,
  accessToken: string,
  table: "audio_manifests" | "sentences" | "learning_events",
  id: string,
  fetchImpl: FetchLike,
): Promise<Array<Record<string, unknown>>> {
  const query = `?select=id&id=eq.${encodeURIComponent(id)}`;
  const response = await fetchImpl(
    `${config.supabaseURL}/rest/v1/${table}${query}`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: config.publishableKey,
      },
    },
  );
  const payload = await readJSON(response);
  if (!response.ok) throwFunctionError(`RLS ${table}`, response, payload);
  if (!Array.isArray(payload)) {
    throw new Error(`RLS ${table} returned an invalid row set`);
  }
  return payload.filter((row): row is Record<string, unknown> =>
    Boolean(row && typeof row === "object")
  );
}

async function prepareRlsChecks(
  config: RemoteAcceptanceConfig,
  primaryToken: string,
  fetchImpl: FetchLike,
): Promise<RlsPreflight> {
  let secondaryToken: string | null = null;
  if (config.secondaryEmail && config.secondaryPassword) {
    secondaryToken = await signInAccount(
      { email: config.secondaryEmail, password: config.secondaryPassword },
      config,
      fetchImpl,
    );
  }

  const sentenceFixture = await checkOptionalFixture(
    config,
    primaryToken,
    secondaryToken,
    "sentences",
    config.rlsSentenceId,
    fetchImpl,
  );
  const eventFixture = await checkOptionalFixture(
    config,
    primaryToken,
    secondaryToken,
    "learning_events",
    config.rlsEventId,
    fetchImpl,
  );

  return { secondaryToken, sentenceFixture, eventFixture };
}

async function runRlsChecks(
  config: RemoteAcceptanceConfig,
  primaryToken: string,
  manifestId: string,
  fetchImpl: FetchLike,
  preflight: RlsPreflight,
): Promise<RlsCheckResult> {
  const ownAudioRows = await readRlsRows(
    config,
    primaryToken,
    "audio_manifests",
    manifestId,
    fetchImpl,
  );
  if (ownAudioRows.length === 0) {
    throw new Error("ordinary JWT cannot read its own audio manifest");
  }

  let secondaryAccount: "not_configured" | "isolated" = "not_configured";
  if (preflight.secondaryToken) {
    const secondaryAudioRows = await readRlsRows(
      config,
      preflight.secondaryToken,
      "audio_manifests",
      manifestId,
      fetchImpl,
    );
    if (secondaryAudioRows.length > 0) {
      throw new Error("secondary account can read the primary audio manifest");
    }
    secondaryAccount = "isolated";
  }

  return {
    ordinaryJwt: true,
    ownAudioManifestVisible: true,
    secondaryAccount,
    sentenceFixture: preflight.sentenceFixture,
    eventFixture: preflight.eventFixture,
    // API calls cannot establish browser/device UI behavior.
    crossDeviceUI: "not_verified",
  };
}

async function checkOptionalFixture(
  config: RemoteAcceptanceConfig,
  primaryToken: string,
  secondaryToken: string | null,
  table: "sentences" | "learning_events",
  fixtureId: string | undefined,
  fetchImpl: FetchLike,
): Promise<"not_configured" | "isolated"> {
  if (!fixtureId) return "not_configured";
  if (!secondaryToken) {
    throw new Error(
      `${table} RLS fixture requires a configured secondary test account`,
    );
  }
  const primaryRows = await readRlsRows(
    config,
    primaryToken,
    table,
    fixtureId,
    fetchImpl,
  );
  if (primaryRows.length === 0) {
    throw new Error(
      `configured ${table} RLS fixture is not visible to primary account`,
    );
  }
  const secondaryRows = await readRlsRows(
    config,
    secondaryToken,
    table,
    fixtureId,
    fetchImpl,
  );
  if (secondaryRows.length > 0) {
    throw new Error(
      `secondary account can read the configured ${table} fixture`,
    );
  }
  return "isolated";
}

async function readAudioSample(
  path: string,
  readFile: (path: string) => Promise<Uint8Array>,
): Promise<File> {
  const extension = extensionForPath(path);
  if (!extension) {
    throw new Error("supplied audio sample must be .webm, .mp4, .ogg, or .wav");
  }
  let bytes: Uint8Array;
  try {
    bytes = await readFile(path);
  } catch {
    throw new Error("unable to read supplied audio sample");
  }
  if (bytes.byteLength < 1) {
    throw new Error("supplied audio sample must not be empty");
  }
  if (bytes.byteLength > MAX_SPEECH_FILE_BYTES) {
    throw new Error("supplied audio sample exceeds the 10 MiB limit");
  }
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return new File([copy.buffer], `acceptance.${extension}`, {
    type: mimeForExtension(extension),
  });
}

function throwFunctionError(
  functionName: string,
  response: Response,
  payload: unknown,
): never {
  // Only fixed error codes are surfaced; response bodies may contain user text.
  const code = safeErrorCode(payload);
  throw new Error(
    `${functionName} failed with HTTP ${response.status}: ${code}`,
  );
}

function safeErrorCode(payload: unknown): string {
  if (!payload || typeof payload !== "object" || !("error" in payload)) {
    return "unknown_error";
  }
  const value = (payload as Record<string, unknown>).error;
  if (typeof value !== "string" || !/^[a-z0-9_:-]{1,64}$/i.test(value)) {
    return "unknown_error";
  }
  return value;
}

function assertRequestBounds(counts: RequestCounts): void {
  const replayBound = 2;
  for (const [name, count] of Object.entries(counts)) {
    if (
      name === "speech-transcribe" || name === "sentences-generate" ||
      name === "sentences-prepare" || name === "sentences-batch-generate" ||
      name === "audio-generate"
    ) {
      if (count > replayBound) {
        throw new Error(`${name} exceeded one attempt plus one replay`);
      }
    }
  }
}

function incrementCount(counts: RequestCounts, name: string): void {
  counts[name] = (counts[name] ?? 0) + 1;
}

function createRunId(): string {
  return crypto.randomUUID();
}

function stableUUID(seed: string): string {
  // Request IDs only need deterministic, UUID-shaped run scoping. The run ID
  // itself is random for new executions; no sensitive text enters this seed.
  const states = [
    0x811c9dc5,
    0x9e3779b1,
    0x85ebca77,
    0xc2b2ae3d,
  ];
  for (let index = 0; index < seed.length; index += 1) {
    const code = seed.charCodeAt(index);
    for (let stateIndex = 0; stateIndex < states.length; stateIndex += 1) {
      states[stateIndex] = Math.imul(
        states[stateIndex] ^ (code + (stateIndex + 1) * 17),
        0x01000193,
      ) >>> 0;
    }
  }
  const hex = states.map((state) => state.toString(16).padStart(8, "0"))
    .join("").split("");
  hex[12] = "4";
  hex[16] = ((Number.parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
  const compact = hex.join("");
  return `${compact.slice(0, 8)}-${compact.slice(8, 12)}-${
    compact.slice(12, 16)
  }-${compact.slice(16, 20)}-${compact.slice(20)}`;
}

function firstTrimmed(
  ...values: Array<string | undefined>
): string | undefined {
  for (const value of values) {
    if (value?.trim()) return value.trim();
  }
  return undefined;
}

function parseDuration(value: string | undefined, label: string): number {
  const parsed = Number(value?.trim() ?? "");
  assertDuration(parsed, label);
  return parsed;
}

function assertDuration(value: number, label: string): void {
  if (
    !Number.isSafeInteger(value) || value < 1 ||
    value > MAX_SPEECH_DURATION_MS
  ) {
    throw new Error(`${label} must be an integer from 1 to 180000`);
  }
}

function assertUUID(value: string, label: string): void {
  if (!UUID_PATTERN.test(value)) throw new Error(`${label} must be a UUID`);
}

function extensionForPath(
  path: string,
): "webm" | "mp4" | "ogg" | "wav" | null {
  const name = path.split(/[\\/]/).pop()?.toLowerCase() ?? "";
  const extension = name.split(".").pop();
  if (
    extension === "webm" || extension === "mp4" || extension === "ogg" ||
    extension === "wav"
  ) return extension;
  if (extension === "m4a") return "mp4";
  return null;
}

function extensionForMime(
  mimeType: string,
): "webm" | "mp4" | "ogg" | "wav" | null {
  const normalized = mimeType.split(";", 1)[0].trim().toLowerCase();
  if (normalized === "audio/webm") return "webm";
  if (normalized === "audio/mp4") return "mp4";
  if (normalized === "audio/ogg") return "ogg";
  if (normalized === "audio/wav" || normalized === "audio/x-wav") return "wav";
  return null;
}

function mimeForExtension(
  extension: "webm" | "mp4" | "ogg" | "wav",
): string {
  if (extension === "webm") return "audio/webm";
  if (extension === "mp4") return "audio/mp4";
  if (extension === "ogg") return "audio/ogg";
  return "audio/wav";
}

function usageLines(): string[] {
  return [
    "Usage: deno run --allow-net --allow-env --allow-read supabase/scripts/remote_acceptance.ts [--execute] [--resume <run-id>] [--audio-file <path>]",
    ...dryRunSummary(),
  ];
}

async function main(): Promise<void> {
  const options = parseOptions(Deno.args);
  const result = await runRemoteAcceptanceCommand(
    Deno.args,
    options.execute && !options.help ? readExecuteEnvironment() : {},
  );
  if (Array.isArray(result.lines)) {
    for (const line of result.lines) console.log(line);
    return;
  }
  console.log(JSON.stringify(result));
}

/** Read only the execute-mode variables; dry-run must work without env access. */
function readExecuteEnvironment(): Record<string, string | undefined> {
  const names = [
    "REMOTE_ACCEPTANCE_ALLOW_BILLABLE",
    "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_TEST_EMAIL",
    "SUPABASE_TEST_PASSWORD",
    "SUPABASE_TEST_EMAIL_2",
    "SUPABASE_TEST_PASSWORD_2",
    "SUPABASE_TEST_EMAIL_SECONDARY",
    "SUPABASE_TEST_PASSWORD_SECONDARY",
    "REMOTE_ACCEPTANCE_AUDIO_FILE",
    "SUPABASE_TEST_AUDIO_FILE",
    "REMOTE_ACCEPTANCE_AUDIO_DURATION_MS",
    "SUPABASE_RLS_SENTENCE_ID",
    "SUPABASE_RLS_EVENT_ID",
  ] as const;
  return Object.fromEntries(names.map((name) => [name, Deno.env.get(name)]));
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(
      error instanceof Error ? error.message : "remote acceptance failed",
    );
    Deno.exit(1);
  }
}
