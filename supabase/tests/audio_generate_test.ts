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
  TTS_MODEL,
  TTS_SPEED,
  VOICE_MAP,
} from "../functions/_shared/audio.ts";
import {
  buildTTSRequest,
  validateAudioGenerationInput,
} from "../functions/_shared/audio_contract.ts";
import {
  AUDIO_GENERATION_TTL_MS,
  shouldReuseInFlightGeneration,
} from "../functions/_shared/audio_generation_policy.ts";
import {
  type AudioHandlerDependencies,
  createAudioGenerateHandler,
  type AudioSupabaseClient,
} from "../functions/audio-generate/index.ts";

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

function makeRequest(clientRequestId = REQUEST_ID): Request {
  return new Request("https://example.test/functions/v1/audio-generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      sentenceId: "sentence-1",
      targetText: "Hello world",
      voiceProfile: "gentle-natural",
      clientRequestId,
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
    tts_model: TTS_MODEL,
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

function mp3Bytes(): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(1024);
  bytes.set([0x49, 0x44, 0x33]);
  return bytes;
}

function fakeAudioDependencies(
  options: {
    manifest?: FakeManifest | null;
    storedAudio?: Uint8Array;
    uploadFailures?: number;
    signedError?: boolean;
    providerResponse?: Response | Promise<Response>;
    onProviderCall?: () => void;
    claimDecisions?: Array<Record<string, unknown>>;
  } = {},
): {
  deps: AudioHandlerDependencies;
  calls: {
    rpc: Array<{ name: string; args: Record<string, unknown> }>;
    fetch: Request[];
    upload: Array<{ path: string; byteLength: number }>;
    download: string[];
    signed: Array<{ path: string; ttl: number }>;
  };
  getManifest: () => FakeManifest | null;
} {
  const calls = {
    rpc: [] as Array<{ name: string; args: Record<string, unknown> }>,
    fetch: [] as Request[],
    upload: [] as Array<{ path: string; byteLength: number }>,
    download: [] as string[],
    signed: [] as Array<{ path: string; ttl: number }>,
  };
  let manifest = options.manifest === undefined
    ? null
    : structuredClone(options.manifest);
  const storedObjects = new Map<string, Uint8Array>();
  if (manifest?.storage_path && options.storedAudio) {
    storedObjects.set(manifest.storage_path, options.storedAudio);
  }
  let uploadAttempt = 0;
  let claimAttempt = 0;

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
              const cutoffFilter = filters.find((filter) =>
                filter.key === "updated_at" && filter.op === "lt"
              );
              const allowedStatus = Array.isArray(statusFilter?.value) &&
                statusFilter.value.includes(manifest.generation_status);
              const beforeCutoff = cutoffFilter &&
                new Date(manifest.updated_at).getTime() <
                  new Date(String(cutoffFilter.value)).getTime();
              if (!allowedStatus || !beforeCutoff) {
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
        };
      },
    },
  };

  const deps: AudioHandlerDependencies = {
    env: {
      get(name: string) {
        return {
          OPENAI_API_KEY: "test-openai-key",
          SUPABASE_URL: "https://example.supabase.co",
          SUPABASE_SERVICE_ROLE_KEY: "test-service-role-key",
        }[name];
      },
    },
    requireAuth: () => USER_ID,
    createSupabase: () => supabase as unknown as AudioSupabaseClient,
    fetch: (input: Request | URL | string, init?: RequestInit) => {
      calls.fetch.push(
        input instanceof Request ? input : new Request(input, init),
      );
      options.onProviderCall?.();
      return Promise.resolve(
        options.providerResponse ??
          new Response(mp3Bytes()),
      );
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

// ============================================================
// Voice Map
// ============================================================

Deno.test("VOICE_MAP maps gentle-natural to nova", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "nova");
});

Deno.test("VOICE_MAP maps clear-slow to sage", () => {
  assertEquals(VOICE_MAP["clear-slow"], "sage");
});

Deno.test("VOICE_MAP maps daily-bright to ash", () => {
  assertEquals(VOICE_MAP["daily-bright"], "ash");
});

// ============================================================
// TTS API Configuration
// ============================================================

Deno.test("Uses tts-1 model", () => {
  assertEquals(TTS_MODEL, "tts-1");
});

Deno.test("Uses mp3 format", () => {
  assertEquals(AUDIO_FORMAT, "mp3");
});

Deno.test("Default speed is 0.85", () => {
  assertEquals(TTS_SPEED, 0.85);
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

Deno.test("Builds the OpenAI TTS request from validated input", () => {
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
  assertEquals(buildTTSRequest(result.targetText, result.openaiVoice), {
    model: "tts-1",
    input: "Hello world",
    voice: "nova",
    response_format: "mp3",
    speed: 0.85,
  });
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

Deno.test("retries Storage upload a bounded number of times without another TTS call", async () => {
  const { deps, calls, getManifest } = fakeAudioDependencies({
    uploadFailures: 2,
  });

  const response = await createAudioGenerateHandler(deps)(makeRequest());

  assertEquals(response.status, 200);
  assertEquals(calls.fetch.length, 1);
  assertEquals(calls.upload.length, 3);
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
  assertEquals(setup.calls.fetch.length, 1);
  assertEquals(setup.calls.download.length, 1);
  assertEquals((await responseBody(response)).cacheHit, false);
});

Deno.test("rejects an invalid provider audio body before writing Storage", async () => {
  const setup = fakeAudioDependencies({
    providerResponse: new Response(new Uint8Array(1024)),
  });
  const response = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 502);
  assertEquals(setup.calls.fetch.length, 1);
  assertEquals(setup.calls.upload.length, 0);
});

Deno.test("does not synthesize again when signed URL delivery fails after audio is ready", async () => {
  const setup = fakeAudioDependencies({ signedError: true });
  const first = await createAudioGenerateHandler(setup.deps)(makeRequest());
  assertEquals(first.status, 503);
  assertEquals(setup.calls.fetch.length, 1);
  assertEquals(setup.getManifest()?.generation_status, "ready");

  const second = await createAudioGenerateHandler(setup.deps)(
    makeRequest(SECOND_REQUEST_ID),
  );

  assertEquals(second.status, 503);
  const body = await responseBody(second);
  assertEquals(body.error, "signed_url_failed");
  assertEquals(setup.calls.fetch.length, 1);
  assertEquals(setup.calls.upload.length, 1);
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
  assertEquals(setup.calls.fetch.length, 1);
  assertEquals(setup.getManifest()?.generation_status, "ready");
});

Deno.test("Claims capacity before calling the TTS provider", () => {
  const claimIndex = FUNCTION_SOURCE.indexOf("claim_generation_request");
  const providerIndex = FUNCTION_SOURCE.indexOf(
    "https://api.openai.com/v1/audio/speech",
  );
  assertEquals(claimIndex >= 0, true);
  assertEquals(providerIndex > claimIndex, true);
});

Deno.test("Completes or fails the audio request ledger", () => {
  assertStringIncludes(FUNCTION_SOURCE, "complete_generation_request");
  assertStringIncludes(FUNCTION_SOURCE, "fail_generation_request");
});
