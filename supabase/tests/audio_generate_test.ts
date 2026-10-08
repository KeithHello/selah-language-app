// Edge Function: audio-generate - Input Validation Tests
// Run: deno test supabase/tests/audio_generate_test.ts

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  contentHash,
  sha256,
  TTS_MODEL,
  TTS_SPEED,
  VOICE_MAP,
} from "../functions/_shared/audio.ts";
import { validateAudioGenerationInput } from "../functions/_shared/audio_contract.ts";
import {
  AUDIO_GENERATION_TTL_MS,
  shouldReuseInFlightGeneration,
} from "../functions/_shared/audio_generation_policy.ts";
import {
  type AudioHandlerDependencies,
  type AudioSupabaseClient,
  createAudioGenerateHandler,
} from "../functions/audio-generate/index.ts";
import { AUDIO_NORMALIZER_REVISION } from "../functions/_shared/audio.ts";

const FUNCTION_SOURCE = await Deno.readTextFile(
  "supabase/functions/audio-generate/index.ts",
);

const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";
const REQUEST_ID = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";
const SECOND_REQUEST_ID = "943f2c8e-4f0e-4a37-b63d-51c4ab25d1f1";
const SIGNED_URL = "https://example.test/signed-audio";
const CONTENT_HASH = await contentHash("Hello world", "gentle-natural");

interface FakeManifest {
  id: string;
  owner_user_id: string | null;
  sentence_id: string | null;
  seed_sentence_id: string | null;
  scope_key: string;
  voice_profile: string;
  content_hash: string;
  storage_path: string | null;
  tts_model: string;
  speed: number;
  audio_format: string;
  byte_size: number;
  duration_ms: number;
  sha256: string | null;
  generation_status: "queued" | "generating" | "ready" | "failed";
  error_code: string | null;
  created_at: string;
  updated_at: string;
  last_accessed_at: string | null;
  [key: string]: unknown;
}

function makeRequest(
  clientRequestId = REQUEST_ID,
  overrides: Record<string, unknown> = {},
): Request {
  return new Request("https://example.test/functions/v1/audio-generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      sentenceId: "sentence-1",
      targetText: "Hello world",
      voiceProfile: "gentle-natural",
      clientRequestId,
      ...overrides,
    }),
  });
}

function makeManifest(overrides: Partial<FakeManifest> = {}): FakeManifest {
  const now = new Date().toISOString();
  return {
    id: "manifest-1",
    owner_user_id: USER_ID,
    sentence_id: "sentence-1",
    seed_sentence_id: null,
    scope_key: `user:${USER_ID}`,
    voice_profile: "gentle-natural",
    content_hash: CONTENT_HASH,
    storage_path:
      `users/${USER_ID}/sentence-1/gentle-natural/${CONTENT_HASH}.mp3`,
    tts_model: `${TTS_MODEL}/en-US-JennyNeural`,
    speed: TTS_SPEED,
    audio_format: AUDIO_FORMAT,
    byte_size: 0,
    duration_ms: 0,
    sha256: null,
    generation_status: "generating",
    error_code: null,
    created_at: now,
    updated_at: now,
    last_accessed_at: null,
    ...overrides,
  };
}

function mp3Bytes(fill = 0): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(1024);
  bytes.set([0x49, 0x44, 0x33]);
  bytes.fill(fill, 3);
  return bytes;
}

function fakeAudioDependencies(
  options: {
    manifest?: FakeManifest | null;
    storedAudio?: Uint8Array;
    storedSourceAudio?: Uint8Array;
    uploadFailures?: number;
    signedError?: boolean;
    providerResponse?: Response | Promise<Response>;
    providerResponses?: Array<Response | Promise<Response>>;
    normalizerResponses?: Response[];
    providerError?: Error;
    envOverrides?: Record<string, string>;
    onProviderCall?: () => void;
    claimDecisions?: Array<Record<string, unknown>>;
  } = {},
): {
  deps: AudioHandlerDependencies;
  calls: {
    rpc: Array<{ name: string; args: Record<string, unknown> }>;
    fetch: Request[];
    usageModels: string[];
    upload: Array<{ path: string; byteLength: number }>;
    download: string[];
    remove: string[][];
    signed: Array<{ path: string; ttl: number }>;
  };
  getManifest: () => FakeManifest | null;
} {
  const calls = {
    rpc: [] as Array<{ name: string; args: Record<string, unknown> }>,
    fetch: [] as Request[],
    usageModels: [] as string[],
    upload: [] as Array<{ path: string; byteLength: number }>,
    download: [] as string[],
    remove: [] as string[][],
    signed: [] as Array<{ path: string; ttl: number }>,
  };
  let manifest = options.manifest === undefined
    ? null
    : structuredClone(options.manifest);
  const storedObjects = new Map<string, Uint8Array>();
  if (manifest?.storage_path && options.storedAudio) {
    storedObjects.set(manifest.storage_path, options.storedAudio);
  }
  if (manifest?.storage_path && options.storedSourceAudio) {
    storedObjects.set(
      manifest.storage_path.replace(/\.mp3$/, ".source.mp3"),
      options.storedSourceAudio,
    );
  }
  let uploadAttempt = 0;
  let claimAttempt = 0;
  let providerAttempt = 0;
  let normalizerAttempt = 0;

  const queryBuilderFor = (tableName: string) => {
    const filters: Array<
      { key: string; op: "eq" | "neq" | "in" | "lt"; value: unknown }
    > = [];
    let action: "update" | "insert" | null = null;
    let payload: Record<string, unknown> | null = null;
    const builder = {
      select() {
        return builder;
      },
      eq(key: string, value: unknown) {
        filters.push({ key, op: "eq", value });
        return builder;
      },
      neq(key: string, value: unknown) {
        filters.push({ key, op: "neq", value });
        return builder;
      },
      in(key: string, value: unknown) {
        filters.push({ key, op: "in", value });
        return builder;
      },
      lt(key: string, value: unknown) {
        filters.push({ key, op: "lt", value });
        return builder;
      },
      update(values: Record<string, unknown>) {
        action = "update";
        payload = values;
        return builder;
      },
      insert(values: Record<string, unknown>) {
        action = "insert";
        payload = values;
        return builder;
      },
      maybeSingle: () =>
        Promise.resolve({
          data: tableName === "audio_manifests" && manifest
            ? structuredClone(manifest)
            : null,
          error: null,
        }),
      single: () =>
        Promise.resolve().then(() => {
          if (
            tableName === "generation_usage_attempts" && action === "insert"
          ) {
            calls.usageModels.push(String(payload?.model));
            return { data: { id: "usage-attempt-1" }, error: null };
          }
          if (action === "insert" && tableName === "audio_manifests") {
            if (manifest) {
              return {
                data: null,
                error: { code: "23505", message: "conflict" },
              };
            }
            manifest = makeManifest(
              payload as unknown as Partial<FakeManifest>,
            );
            return { data: structuredClone(manifest), error: null };
          }
          if (
            action === "update" && tableName === "audio_manifests" && payload
          ) {
            const idFilter = filters.find((filter) =>
              filter.key === "id" && filter.op === "eq"
            );
            if (!manifest || idFilter?.value !== manifest.id) {
              return { data: null, error: { code: "PGRST116" } };
            }
            if (payload.generation_status === "ready") {
              const blockedByStatus = filters.some((filter) =>
                filter.key === "generation_status" &&
                filter.op === "neq" &&
                filter.value === manifest?.generation_status
              );
              if (blockedByStatus) {
                return { data: null, error: { code: "PGRST116" } };
              }
            }
            if (payload.generation_status === "generating") {
              const statusFilter = filters.find((filter) =>
                filter.key === "generation_status" && filter.op === "in"
              );
              const readyFilter = filters.find((filter) =>
                filter.key === "generation_status" && filter.op === "eq"
              );
              const modelFilter = filters.find((filter) =>
                filter.key === "tts_model" && filter.op === "eq"
              );
              const cutoffFilter = filters.find((filter) =>
                filter.key === "updated_at" && filter.op === "lt"
              );
              const allowedStatus = Array.isArray(statusFilter?.value) &&
                statusFilter.value.includes(manifest.generation_status);
              const beforeCutoff = cutoffFilter &&
                new Date(manifest.updated_at).getTime() <
                  new Date(String(cutoffFilter.value)).getTime();
              const failedRecovery = filters.some((filter) =>
                filter.key === "generation_status" &&
                filter.op === "eq" &&
                filter.value === "failed"
              ) && manifest.generation_status === "failed";
              const replacingReadyManifest = readyFilter?.value === "ready" &&
                manifest.generation_status === "ready" &&
                modelFilter?.value === manifest.tts_model;
              if (
                !replacingReadyManifest &&
                !failedRecovery &&
                (!allowedStatus || !beforeCutoff)
              ) {
                return { data: null, error: { code: "PGRST116" } };
              }
            }
            manifest = {
              ...manifest,
              ...payload,
              updated_at: new Date().toISOString(),
            } as FakeManifest;
            return { data: structuredClone(manifest), error: null };
          }
          return { data: null, error: { code: "UNSUPPORTED_QUERY" } };
        }),
      then(onFulfilled: (value: unknown) => unknown) {
        return Promise.resolve({ data: null, error: null }).then(onFulfilled);
      },
    };
    return builder;
  };
  const supabase = {
    rpc: (name: string, args: Record<string, unknown>) =>
      Promise.resolve().then(() => {
        calls.rpc.push({ name, args });
        if (name === "claim_generation_request") {
          const decision = options.claimDecisions?.[claimAttempt];
          claimAttempt += 1;
          return {
            data: decision ?? {
              decision: "claimed",
              retryAfterSeconds: 0,
              responsePayload: null,
            },
            error: null,
          };
        }
        if (name === "complete_generation_request") {
          return { data: true, error: null };
        }
        if (name === "fail_generation_request") {
          return { data: true, error: null };
        }
        if (name === "get_platform_service_controls") {
          return { data: null, error: new Error("controls unavailable") };
        }
        if (name === "reserve_generation_allowance") {
          return { data: "test-reservation-id", error: null };
        }
        if (name === "record_generation_usage") {
          return {
            data: { reservationId: "test-usage-reservation-id" },
            error: null,
          };
        }
        if (name === "settle_generation_allowance") {
          return { data: true, error: null };
        }
        return { data: null, error: new Error("unexpected rpc") };
      }),
    from: (table: string) => {
      if (
        table === "audio_manifests" ||
        table === "generation_usage_attempts" ||
        table === "generation_business_events"
      ) {
        return queryBuilderFor(table);
      }
      throw new Error(`unexpected table ${table}`);
    },
    storage: {
      from: (bucket: string) => {
        assertEquals(bucket, AUDIO_BUCKET);
        return {
          download: (path: string) =>
            Promise.resolve().then(() => {
              calls.download.push(path);
              const data = storedObjects.get(path);
              return data
                ? { data: new Blob([new Uint8Array(data)]), error: null }
                : { data: null, error: { message: "not found" } };
            }),
          upload: (path: string, body: Uint8Array) =>
            Promise.resolve().then(() => {
              uploadAttempt += 1;
              calls.upload.push({ path, byteLength: body.byteLength });
              if (uploadAttempt <= (options.uploadFailures ?? 0)) {
                return { error: { message: "upload failed" } };
              }
              storedObjects.set(path, body);
              return { error: null };
            }),
          createSignedUrl: (path: string, ttl: number) =>
            Promise.resolve().then(() => {
              calls.signed.push({ path, ttl });
              return options.signedError
                ? { data: null, error: { message: "sign failed" } }
                : { data: { signedUrl: SIGNED_URL }, error: null };
            }),
          remove: (paths: string[]) =>
            Promise.resolve().then(() => {
              calls.remove.push(paths);
              for (const path of paths) storedObjects.delete(path);
              return { error: null };
            }),
        };
      },
    },
  };

  const deps: AudioHandlerDependencies = {
    env: {
      get(name: string) {
        return {
          SUPABASE_URL: "https://example.supabase.co",
          SUPABASE_SERVICE_ROLE_KEY: "test-service-role-key",
          AZURE_SPEECH_KEY: "test-azure-key",
          AZURE_SPEECH_REGION: "japaneast",
          AUDIO_NORMALIZER_URL: "https://normalizer.example.test",
          AUDIO_NORMALIZER_TOKEN: "normalizer-test-token-that-is-long-enough",
          AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER: "15000",
          AUDIO_NORMALIZER_NANO_USD_PER_REQUEST: "5000",
          AZURE_TTS_PRICE_VERSION: "azure-test-resource-v1",
          ...options.envOverrides,
        }[name];
      },
    },
    requireAuth: () => USER_ID,
    createSupabase: () => supabase as unknown as AudioSupabaseClient,
    fetch: async (input: Request | URL | string, init?: RequestInit) => {
      const request = input instanceof Request
        ? input
        : new Request(input, init);
      calls.fetch.push(request);
      if (new URL(request.url).hostname === "normalizer.example.test") {
        const response = options.normalizerResponses?.[normalizerAttempt];
        normalizerAttempt += 1;
        if (response) return response;
        const normalized = mp3Bytes(2);
        return new Response(normalized, {
          headers: {
            "Content-Type": "audio/mpeg",
            "X-Audio-Normalizer-Revision": "lufs-v1",
            "X-Audio-SHA256": await sha256(normalized.buffer),
            "X-Audio-Integrated-Lufs": "-22.0",
            "X-Audio-True-Peak-Dbtp": "-1.2",
            "X-Audio-Duration-Ms": "1200",
            "X-Audio-Sample-Rate": "24000",
            "X-Audio-Channels": "1",
            "X-Audio-Normalization-Mode": "linear",
          },
        });
      }
      options.onProviderCall?.();
      const currentAttempt = providerAttempt++;
      const response = options.providerResponses?.[currentAttempt] ??
        options.providerResponse;
      if (options.providerError && currentAttempt === 0) {
        throw options.providerError;
      }
      return response ?? new Response(mp3Bytes());
    },
    sleep: async () => {},
  };

  return { deps, calls, getManifest: () => manifest };
}

async function responseBody(
  response: Response,
): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

function azureRequests(calls: { fetch: Request[] }): Request[] {
  return calls.fetch.filter((request) =>
    new URL(request.url).hostname.endsWith("tts.speech.microsoft.com")
  );
}

function normalizerRequests(calls: { fetch: Request[] }): Request[] {
  return calls.fetch.filter((request) =>
    new URL(request.url).hostname === "normalizer.example.test"
  );
}

// ============================================================
// Azure Voice Map and Generation
// ============================================================

Deno.test("voice profiles map to Azure neural voices", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "en-US-JennyNeural");
  assertEquals(VOICE_MAP["clear-slow"], "en-US-JennyNeural");
  assertEquals(VOICE_MAP["daily-bright"], "en-US-GuyNeural");
  assertEquals(VOICE_MAP["elegant-british"], "en-GB-SoniaNeural");
  assertEquals(VOICE_MAP["native-gentle"], "zh-TW-HsiaoChenNeural");
});

Deno.test("uses Azure speech model and MP3 output", () => {
  assertEquals(TTS_MODEL, "azure-speech");
  assertEquals(AUDIO_FORMAT, "mp3");
  assertEquals(TTS_SPEED, 1);
});

Deno.test("routes Chinese source audio through Azure then normalization", async () => {
  const setup = fakeAudioDependencies();
  const response = await createAudioGenerateHandler(setup.deps)(
    makeRequest(REQUEST_ID, {
      contractVersion: 2,
      text: "你好，最近好吗？",
      targetText: undefined,
      audioRole: "source",
      sourceLanguage: "zh-Hant",
      targetLanguage: "en",
      accent: "zh-TW",
      voiceProfile: "native-gentle",
    }),
  );
  const azure = azureRequests(setup.calls);
  assertEquals(response.status, 200);
  assertEquals(azure.length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertStringIncludes(
    azure[0].url,
    "https://japaneast.tts.speech.microsoft.com/cognitiveservices/v1",
  );
  assertEquals(
    azure[0].headers.get("Ocp-Apim-Subscription-Key"),
    "test-azure-key",
  );
  assertStringIncludes(await azure[0].text(), "HsiaoChenNeural");
  assertEquals(
    setup.getManifest()?.tts_model,
    "azure-speech/zh-TW-HsiaoChenNeural",
  );
  assertEquals(setup.calls.upload.length, 2);
  assertEquals(setup.calls.upload[0].path.endsWith(".source.mp3"), true);
  assertEquals(setup.calls.remove.length, 1);
  const body = await responseBody(response);
  assertEquals(body.provider, "azure");
  assertEquals(body.normalizerRevision, AUDIO_NORMALIZER_REVISION);
  assertEquals(body.cacheKeyVersion, "v3");
});

Deno.test("uses Azure voices and locales for Japanese and English tracks", async () => {
  const cases = [
    {
      text: "おはようございます。",
      audioRole: "source",
      sourceLanguage: "ja",
      targetLanguage: "en",
      accent: "ja-JP",
      voiceProfile: "native-gentle",
      voice: "ja-JP-NanamiNeural",
      locale: "ja-JP",
    },
    {
      text: "Good morning.",
      audioRole: "target",
      sourceLanguage: "zh-Hant",
      targetLanguage: "en",
      accent: "en-GB",
      voiceProfile: "elegant-british",
      voice: "en-GB-SoniaNeural",
      locale: "en-GB",
    },
  ] as const;

  for (const [index, item] of cases.entries()) {
    const setup = fakeAudioDependencies();
    const response = await createAudioGenerateHandler(setup.deps)(
      makeRequest(index === 0 ? REQUEST_ID : SECOND_REQUEST_ID, {
        contractVersion: 2,
        ...item,
        targetText: undefined,
      }),
    );
    const azure = azureRequests(setup.calls);
    assertEquals(response.status, 200);
    assertEquals(azure.length, 1);
    assertEquals(normalizerRequests(setup.calls).length, 1);
    const ssml = await azure[0].text();
    assertStringIncludes(ssml, item.voice);
    assertStringIncludes(ssml, `xml:lang="${item.locale}"`);
    assertEquals(setup.getManifest()?.tts_model, `azure-speech/${item.voice}`);
  }
});

Deno.test("retries a provider timeout once and then normalizes the successful audio", async () => {
  const setup = fakeAudioDependencies({
    providerError: new Error("network timeout"),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 200);
  assertEquals(azureRequests(setup.calls).length, 2);
  assertEquals(normalizerRequests(setup.calls).length, 1);
});

Deno.test("does not fall back to OpenAI after an Azure authorization failure", async () => {
  const setup = fakeAudioDependencies({
    providerResponse: new Response("Unauthorized", { status: 401 }),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 502);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 0);
  assertEquals(
    setup.calls.fetch.some((request) =>
      new URL(request.url).hostname === "api.openai.com"
    ),
    false,
  );
});

Deno.test("replaces legacy OpenAI cache entries with normalized Azure audio", async () => {
  const setup = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "ready",
      tts_model: "openai/tts-1/alloy",
      byte_size: mp3Bytes().byteLength,
    }),
    storedAudio: mp3Bytes(),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 200);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals(
    setup.getManifest()?.tts_model,
    "azure-speech/en-US-JennyNeural",
  );
  assertEquals((await responseBody(response)).provider, "azure");
});

Deno.test("releases reserved quota after a non-retryable provider 4xx", async () => {
  const setup = fakeAudioDependencies({
    providerResponse: new Response("Bad Request", { status: 400 }),
    envOverrides: { MEMBERSHIP_ENFORCEMENT_ENABLED: "true" },
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 502);
  const settlement = setup.calls.rpc.find((call) =>
    call.name === "settle_generation_allowance"
  );
  assertEquals(settlement?.args.p_status, "released_unsent");
});

Deno.test("retries an unreadable Azure response body without changing providers", async () => {
  const brokenBody = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.error(new Error("provider response body failed"));
    },
  });
  const setup = fakeAudioDependencies({
    providerResponses: [new Response(brokenBody), new Response(mp3Bytes())],
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 200);
  assertEquals(azureRequests(setup.calls).length, 2);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals((await responseBody(response)).provider, "azure");
});

Deno.test("fails closed when Azure credentials or current pricing are missing", async () => {
  const missingCredentials = fakeAudioDependencies({
    envOverrides: { AZURE_SPEECH_KEY: "", AZURE_SPEECH_REGION: "" },
  });
  const providerResponse = await createAudioGenerateHandler(
    missingCredentials.deps,
  )(makeRequest());
  assertEquals(providerResponse.status, 503);
  assertEquals(missingCredentials.calls.fetch.length, 0);

  const missingPrice = fakeAudioDependencies({
    envOverrides: { AZURE_TTS_PRICE_VERSION: "" },
  });
  const pricingResponse = await createAudioGenerateHandler(missingPrice.deps)(
    makeRequest(),
  );
  assertEquals(pricingResponse.status, 503);
  assertEquals(
    (await responseBody(pricingResponse)).error,
    "audio_pricing_unavailable",
  );
  assertEquals(missingPrice.calls.fetch.length, 0);
});

Deno.test("serves a validated Azure cache hit when provider pricing is unavailable", async () => {
  const setup = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "ready",
      byte_size: mp3Bytes().byteLength,
    }),
    storedAudio: mp3Bytes(),
    envOverrides: {
      AZURE_SPEECH_KEY: "",
      AZURE_SPEECH_REGION: "",
      AZURE_TTS_PRICE_VERSION: "",
    },
  });

  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());

  assertEquals(response.status, 200);
  assertEquals((await responseBody(response)).cacheHit, true);
  assertEquals(setup.calls.fetch.length, 0);
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Requires targetText", () => {
  const result = validateAudioGenerationInput({ sentenceId: "sentence-1" });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "missing_audio_input");
});

Deno.test("Validates targetText max length 1000", () => {
  const result = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "a".repeat(1001),
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "text_too_long");
});

Deno.test("Rejects unsupported voice profile", () => {
  const result = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "Hello",
    voiceProfile: "unknown",
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "unsupported_voice_profile");
});

Deno.test("Requires a UUID clientRequestId", () => {
  const missing = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "Hello",
  });
  assertEquals(missing.ok, false);
  if (!missing.ok) assertEquals(missing.code, "invalid_client_request_id");

  const malformed = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "Hello",
    clientRequestId: "not-a-uuid",
  });
  assertEquals(malformed.ok, false);
  if (!malformed.ok) assertEquals(malformed.code, "invalid_client_request_id");
});

// ============================================================
// Output Structure
// ============================================================

Deno.test("validates input into an Azure route with the current cache revision", () => {
  const result = validateAudioGenerationInput({
    sentenceId: " sentence-1 ",
    targetText: " Hello world ",
    voiceProfile: "gentle-natural",
    clientRequestId: "92d4ba92-cb72-421f-bc94-b36ef91bf61c",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.sentenceId, "sentence-1");
  assertEquals(result.targetText, "Hello world");
  assertEquals(
    result.clientRequestId,
    "92d4ba92-cb72-421f-bc94-b36ef91bf61c",
  );
  assertEquals(result.route.provider, "azure");
  assertEquals(result.route.providerVoice, "en-US-JennyNeural@gentle-natural");
  assertEquals(result.route.providerModel, "azure-speech/en-US-JennyNeural");
  assertEquals(AUDIO_NORMALIZER_REVISION, "lufs-v1");
});

Deno.test(
  "Reuses queued and generating manifests to prevent duplicate provider calls",
  () => {
    const fresh = new Date().toISOString();
    const stale = new Date(Date.now() - AUDIO_GENERATION_TTL_MS - 60_000)
      .toISOString();
    assertEquals(shouldReuseInFlightGeneration("queued", fresh, fresh), true);
    assertEquals(
      shouldReuseInFlightGeneration("generating", fresh, fresh),
      true,
    );
    assertEquals(
      shouldReuseInFlightGeneration("generating", stale, fresh),
      false,
    );
    assertEquals(shouldReuseInFlightGeneration("ready"), false);
    assertEquals(shouldReuseInFlightGeneration("failed"), false);
    assertEquals(shouldReuseInFlightGeneration(null), false);
  },
);

Deno.test("reuses a fresh generating manifest without claiming capacity or calling TTS", async () => {
  const { deps, calls } = fakeAudioDependencies({
    manifest: makeManifest({ generation_status: "generating" }),
  });

  const response = await createAudioGenerateHandler(deps)(makeRequest());

  assertEquals(response.status, 202);
  const body = await responseBody(response);
  assertEquals(body.status, "generating");
  assertEquals(body.downloadUrl, null);
  assertEquals(calls.fetch.length, 0);
  assertEquals(calls.rpc.length, 0);
});

Deno.test("recovers an expired generating manifest from Storage without calling TTS", async () => {
  const staleAt = new Date(Date.now() - AUDIO_GENERATION_TTL_MS - 60_000)
    .toISOString();
  const { deps, calls, getManifest } = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "generating",
      updated_at: staleAt,
      error_code: "previous_attempt_unknown",
    }),
    storedAudio: mp3Bytes(),
  });

  const response = await createAudioGenerateHandler(deps)(makeRequest());

  assertEquals(response.status, 200);
  const body = await responseBody(response);
  assertEquals(body.status, "ready");
  assertEquals(body.downloadUrl, SIGNED_URL);
  assertEquals(body.cacheHit, true);
  assertEquals(calls.fetch.length, 0);
  assertEquals(calls.download.length, 1);
  assertEquals(calls.upload.length, 0);
  assertEquals(getManifest()?.generation_status, "ready");
  assert(typeof getManifest()?.sha256 === "string");
});

Deno.test("normalizes a retained source object during stale generation recovery", async () => {
  const staleAt = new Date(Date.now() - AUDIO_GENERATION_TTL_MS - 60_000)
    .toISOString();
  const setup = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "generating",
      updated_at: staleAt,
      error_code: "audio_normalization_failed",
    }),
    storedSourceAudio: mp3Bytes(),
  });

  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());

  assertEquals(response.status, 200);
  assertEquals(azureRequests(setup.calls).length, 0);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals(setup.calls.upload.length, 1);
  assertEquals(setup.getManifest()?.generation_status, "ready");
  assertEquals(setup.calls.remove.length, 1);
});

Deno.test("retries a failed normalization recovery immediately from retained source", async () => {
  const staleAt = new Date(Date.now() - AUDIO_GENERATION_TTL_MS - 60_000)
    .toISOString();
  const setup = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "generating",
      updated_at: staleAt,
      error_code: "audio_normalization_failed",
    }),
    storedSourceAudio: mp3Bytes(),
    normalizerResponses: [new Response("Unavailable", { status: 503 })],
  });
  const handler = createAudioGenerateHandler(setup.deps);

  const first = await handler(makeRequest(REQUEST_ID));
  assertEquals(first.status, 503);
  assertEquals(setup.getManifest()?.generation_status, "failed");
  const second = await handler(makeRequest(SECOND_REQUEST_ID));

  assertEquals(second.status, 200);
  assertEquals(azureRequests(setup.calls).length, 0);
  assertEquals(normalizerRequests(setup.calls).length, 2);
  assertEquals(setup.getManifest()?.generation_status, "ready");
});

Deno.test("retries Storage upload a bounded number of times without another TTS call", async () => {
  const { deps, calls, getManifest } = fakeAudioDependencies({
    uploadFailures: 2,
  });

  const response = await createAudioGenerateHandler(deps)(makeRequest());

  assertEquals(response.status, 200);
  assertEquals(azureRequests(calls).length, 1);
  assertEquals(normalizerRequests(calls).length, 1);
  assertEquals(calls.upload.length, 4);
  assertEquals(getManifest()?.generation_status, "ready");
});

Deno.test("does not recover stored audio with a mismatched known checksum", async () => {
  const setup = fakeAudioDependencies({
    manifest: makeManifest({
      generation_status: "generating",
      updated_at: new Date(Date.now() - AUDIO_GENERATION_TTL_MS - 60_000)
        .toISOString(),
      sha256: "0".repeat(64),
      byte_size: 1024,
    }),
    storedAudio: mp3Bytes(),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 200);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals(setup.calls.download.length, 1);
  assertEquals((await responseBody(response)).cacheHit, false);
});

Deno.test("rejects an invalid provider audio body before writing Storage", async () => {
  const setup = fakeAudioDependencies({
    providerResponse: new Response(new Uint8Array(1024)),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 502);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(setup.calls.upload.length, 0);
});

Deno.test("does not synthesize again when signed URL delivery fails after audio is ready", async () => {
  const setup = fakeAudioDependencies({ signedError: true });
  const first = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(first.status, 503);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals(setup.getManifest()?.generation_status, "ready");

  const second = await createAudioGenerateHandler(setup.deps)(
    makeRequest(SECOND_REQUEST_ID),
  );

  assertEquals(second.status, 503);
  const body = await responseBody(second);
  assertEquals(body.error, "signed_url_failed");
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(setup.calls.upload.length, 2);
});

Deno.test("allows only one concurrent content claim to call TTS", async () => {
  let resolveProvider: (response: Response) => void = () => {};
  const providerPromise = new Promise<Response>((resolve) => {
    resolveProvider = resolve;
  });
  const providerStarted = Promise.withResolvers<void>();
  const setup = fakeAudioDependencies({
    providerResponse: providerPromise,
    onProviderCall: () => providerStarted.resolve(),
  });
  const handler = createAudioGenerateHandler(setup.deps);

  const first = handler(makeRequest(REQUEST_ID));
  await providerStarted.promise;
  const secondResponse = await handler(makeRequest(SECOND_REQUEST_ID));
  resolveProvider(new Response(mp3Bytes()));

  const firstResponse = await first;
  assertEquals(firstResponse.status, 200);
  assertEquals(secondResponse.status, 202);
  assertEquals(azureRequests(setup.calls).length, 1);
  assertEquals(normalizerRequests(setup.calls).length, 1);
  assertEquals(setup.getManifest()?.generation_status, "ready");
});

Deno.test("Claims capacity before calling the TTS provider", () => {
  const claimIndex = FUNCTION_SOURCE.indexOf("claim_generation_request");
  const providerIndex = FUNCTION_SOURCE.indexOf(
    "const request = buildAzureSpeechRequest",
  );
  assertEquals(claimIndex >= 0, true);
  assertEquals(providerIndex > claimIndex, true);
});

Deno.test("Completes or fails the audio request ledger", () => {
  assertStringIncludes(FUNCTION_SOURCE, "complete_generation_request");
  assertStringIncludes(FUNCTION_SOURCE, "fail_generation_request");
});
