#!/usr/bin/env -S deno run --allow-net --allow-env
/**
 * Selah remote acceptance runner.
 *
 * The default mode is dry-run and performs no network request. The execute
 * mode is intentionally billable: it signs in a dedicated test account and
 * exercises sentence preparation, sentence generation replay, batch
 * translation, TTS, and signed audio delivery against a deployed project.
 *
 * Required only for --execute:
 *   SUPABASE_URL
 *   SUPABASE_PUBLISHABLE_KEY
 *   SUPABASE_TEST_EMAIL
 *   SUPABASE_TEST_PASSWORD
 *   REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true
 *
 * Usage:
 *   deno run --allow-net --allow-env supabase/scripts/remote_acceptance.ts
 *   deno run --allow-net --allow-env supabase/scripts/remote_acceptance.ts --execute
 */

const TEST_SENTENCE_ID = "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f01";
const SENTENCE_REQUEST_ID = "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f02";
const PREPARATION_REQUEST_ID = "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f03";
const BATCH_REQUEST_ID = "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f04";
const TEST_TRANSCRIPT = "呃，我今天有點累，但是還是想完成今天的練習。";

export interface RemoteAcceptanceConfig {
  supabaseURL: string;
  publishableKey: string;
  email: string;
  password: string;
}

export interface RemoteAcceptanceOptions {
  execute: boolean;
  help: boolean;
}

export function parseOptions(args: string[]): RemoteAcceptanceOptions {
  return {
    execute: args.includes("--execute"),
    help: args.includes("--help") || args.includes("-h"),
  };
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

  const supabaseURL = required.SUPABASE_URL!.replace(/\/$/, "");
  const parsedURL = new URL(supabaseURL);
  if (parsedURL.protocol !== "https:" || !parsedURL.host) {
    throw new Error("SUPABASE_URL must be an HTTPS URL");
  }

  return {
    supabaseURL,
    publishableKey: required.SUPABASE_PUBLISHABLE_KEY!,
    email: required.SUPABASE_TEST_EMAIL!,
    password: required.SUPABASE_TEST_PASSWORD!,
  };
}

export function dryRunSummary(): string[] {
  return [
    "DRY RUN ONLY: no Supabase, OpenAI, Storage, or auth request will be made.",
    "Planned checks: auth → config bootstrap → long-transcript preparation → sentence generation replay → batch translation → TTS → signed URL download.",
    "Network retry is verified by the Swift reliability tests; this runner checks the deployed endpoint response path.",
    "Use --execute only with a dedicated test account and explicit billable approval.",
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

type FetchLike = typeof fetch;

export async function runRemoteAcceptance(
  config: RemoteAcceptanceConfig,
  fetchImpl: FetchLike = fetch,
): Promise<Record<string, unknown>> {
  const accessToken = await signIn(config, fetchImpl);
  const bootstrap = await callFunction(
    config,
    accessToken,
    "config-bootstrap",
    "GET",
    undefined,
    fetchImpl,
  );
  assertBootstrap(bootstrap);

  const sentenceBody = {
    sourceText: "我今天有點累。",
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    clientRequestId: SENTENCE_REQUEST_ID,
  };
  const sentence = await callFunction(
    config,
    accessToken,
    "sentences-generate",
    "POST",
    sentenceBody,
    fetchImpl,
  ) as Record<string, unknown>;
  const sentenceReplay = await callFunction(
    config,
    accessToken,
    "sentences-generate",
    "POST",
    sentenceBody,
    fetchImpl,
  ) as Record<string, unknown>;
  assertSamePayload(sentence, sentenceReplay, "sentence generation replay");

  const preparationBody = {
    rawTranscript: TEST_TRANSCRIPT,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    clientRequestId: PREPARATION_REQUEST_ID,
  };
  const preparation = await callFunction(
    config,
    accessToken,
    "sentences-prepare",
    "POST",
    preparationBody,
    fetchImpl,
  ) as PreparationPayload;
  const preparationReplay = await callFunction(
    config,
    accessToken,
    "sentences-prepare",
    "POST",
    preparationBody,
    fetchImpl,
  ) as PreparationPayload;
  assertSamePayload(
    preparation,
    preparationReplay,
    "capture preparation replay",
  );

  const segments = normalizeSegments(preparation.segments);
  if (segments.length === 0) {
    throw new Error("capture preparation returned no usable segments");
  }
  const batch = await callFunction(
    config,
    accessToken,
    "sentences-batch-generate",
    "POST",
    {
      clientRequestId: BATCH_REQUEST_ID,
      segments,
      sourceLanguage: "zh-Hant",
      targetLanguage: "en",
    },
    fetchImpl,
  ) as BatchPayload;
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
      sentenceId: TEST_SENTENCE_ID,
      targetText,
      voiceProfile: "gentle-natural",
      reason: "remote_acceptance",
      clientRequestId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f05",
    },
    fetchImpl,
  ) as AudioPayload;
  assertAudio(audio);

  const refreshedAudio = await callFunction(
    config,
    accessToken,
    "audio-download-url",
    "POST",
    { manifestId: audio.manifestId },
    fetchImpl,
  ) as AudioPayload;
  assertAudio(refreshedAudio);

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

  return {
    status: "passed",
    checks: [
      "auth",
      "config-bootstrap",
      "sentence-generation-replay",
      "capture-preparation-replay",
      "batch-translation",
      "tts-generation",
      "signed-url-refresh",
      "audio-download",
    ],
    segmentCount: segments.length,
    audioBytes: audioBytes.byteLength,
    audioCacheHitOnRefresh: refreshedAudio.cacheHit === true,
  };
}

async function signIn(
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
      body: JSON.stringify({ email: config.email, password: config.password }),
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

async function callFunction(
  config: RemoteAcceptanceConfig,
  accessToken: string,
  functionName: string,
  method: "GET" | "POST",
  body: unknown,
  fetchImpl: FetchLike,
): Promise<unknown> {
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
    const code = payload && typeof payload === "object" && "error" in payload
      ? String((payload as Record<string, unknown>).error)
      : "unknown_error";
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
  return value.slice(0, 5).flatMap((item, index) => {
    if (!item || typeof item !== "object") return [];
    const candidate = item as CaptureSegment;
    if (
      typeof candidate.segmentId !== "string" ||
      typeof candidate.sourceText !== "string" ||
      !candidate.sourceText.trim()
    ) return [];
    return [{
      segmentId: candidate.segmentId,
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

function printUsage(): void {
  console.log(
    "Usage: deno run --allow-net --allow-env supabase/scripts/remote_acceptance.ts [--execute]",
  );
  for (const line of dryRunSummary()) console.log(line);
}

async function main(): Promise<void> {
  const options = parseOptions(Deno.args);
  if (options.help) {
    printUsage();
    return;
  }
  if (!options.execute) {
    for (const line of dryRunSummary()) console.log(line);
    return;
  }

  const config = loadExecuteConfig(Deno.env.toObject());
  const result = await runRemoteAcceptance(config);
  console.log(JSON.stringify(result));
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
