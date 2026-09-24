import {
  assertEquals,
  assertExists,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createSpeechTranscribeHandler,
  type SpeechHandlerDependencies,
} from "../functions/speech-transcribe/index.ts";
import {
  MAX_SPEECH_DURATION_MS,
  MAX_SPEECH_FILE_BYTES,
  SPEECH_TRANSCRIPTION_MODEL,
  validateSpeechTranscribeFormData,
} from "../functions/_shared/speech_contract.ts";

const FUNCTION_SOURCE = await Deno.readTextFile(
  "supabase/functions/speech-transcribe/index.ts",
);

const REQUEST_ID = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";
const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";

function makeFormData(overrides: {
  file?: File | null;
  clientRequestId?: string;
  language?: string;
  durationMs?: string;
} = {}): FormData {
  const form = new FormData();
  if (overrides.file !== null) {
    form.append(
      "file",
      overrides.file ??
        new File([new Uint8Array([0x52, 0x49, 0x46, 0x46])], "capture.wav", {
          type: "audio/wav",
        }),
    );
  }
  form.set("clientRequestId", overrides.clientRequestId ?? REQUEST_ID);
  if (overrides.language !== undefined) {
    form.set("language", overrides.language);
  }
  form.set("durationMs", overrides.durationMs ?? "2500");
  return form;
}

function makeRequest(form: FormData): Request {
  return new Request("https://example.test/functions/v1/speech-transcribe", {
    method: "POST",
    body: form,
  });
}

interface UsageSupabase {
  from(table: string): {
    insert(values: Record<string, unknown>): {
      select(columns?: string): {
        single(): Promise<{
          data: { id: string } | null;
          error: unknown;
        }>;
      };
    };
    update(values: Record<string, unknown>): {
      eq(column: string, value: string): Promise<{ error: unknown }>;
    };
  };
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

function fakeDependencies(
  options: {
    claim?: Record<string, unknown>;
    providerResponse?: Response;
    auth?: string | Response;
    env?: Record<string, string>;
  } = {},
): {
  deps: SpeechHandlerDependencies;
  calls: Array<{ name: string; args: Record<string, unknown> }>;
  fetchCalls: Request[];
} {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const fetchCalls: Request[] = [];
  const deps: SpeechHandlerDependencies = {
    env: {
      get(name: string) {
        return options.env?.[name] ?? {
          OPENAI_API_KEY: "test-openai-key",
          SUPABASE_URL: "https://example.supabase.co",
          SUPABASE_SERVICE_ROLE_KEY: "test-service-role-key",
        }[name];
      },
    },
    requireAuth: () => options.auth ?? USER_ID,
    createSupabase: () => {
      const client: UsageSupabase = {
        from: () => ({
          insert: (values) => ({
            select: () => ({
              single: () =>
                Promise.resolve({
                  data: values.provider_status === "started"
                    ? { id: "usage-attempt-1" }
                    : null,
                  error: null,
                }),
            }),
          }),
          update: () => ({
            eq: () => Promise.resolve({ error: null }),
          }),
        }),
        rpc: (name: string, args: Record<string, unknown>) => {
          calls.push({ name, args });
          if (name === "claim_generation_request") {
            return Promise.resolve({
              data: options.claim ?? {
                decision: "claimed",
                retryAfterSeconds: 0,
                responsePayload: null,
              },
              error: null,
            });
          }
          if (name === "get_platform_service_controls") {
            return Promise.resolve({ data: null, error: null });
          }
          if (name === "complete_generation_request") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "fail_generation_request") {
            return Promise.resolve({ data: true, error: null });
          }
          return Promise.resolve({
            data: null,
            error: new Error("unexpected rpc"),
          });
        },
      };
      return client;
    },
    fetch: (input: Request | URL | string, init?: RequestInit) => {
      fetchCalls.push(
        input instanceof Request ? input : new Request(input, init),
      );
      return Promise.resolve(
        options.providerResponse ??
          Response.json({ text: "  I am tired today.  " }),
      );
    },
  };
  return { deps, calls, fetchCalls };
}

async function responseBody(
  response: Response,
): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

Deno.test("validates a supported recording and applies the zh default", () => {
  const result = validateSpeechTranscribeFormData(makeFormData());
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.clientRequestId, REQUEST_ID);
  assertEquals(result.language, "zh");
  assertEquals(result.durationMs, 2500);
  assertEquals(result.mimeType, "audio/wav");
  assertEquals(result.extension, "wav");
  assertEquals(result.file.name, "capture.wav");
});

Deno.test("rejects a recording without a file", () => {
  const result = validateSpeechTranscribeFormData(makeFormData({ file: null }));
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "missing_audio_file");
});

Deno.test("rejects unsupported MIME types even when the filename looks valid", () => {
  const result = validateSpeechTranscribeFormData(
    makeFormData({
      file: new File(["audio"], "capture.webm", { type: "audio/mpeg" }),
    }),
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "unsupported_audio_type");
});

Deno.test("enforces the 10 MB file and 180 second duration limits", () => {
  const large = validateSpeechTranscribeFormData(
    makeFormData({
      file: new File(
        [new Uint8Array(MAX_SPEECH_FILE_BYTES + 1)],
        "capture.webm",
        { type: "audio/webm" },
      ),
    }),
  );
  assertEquals(large.ok, false);
  if (!large.ok) assertEquals(large.code, "audio_file_too_large");

  const long = validateSpeechTranscribeFormData(
    makeFormData({ durationMs: String(MAX_SPEECH_DURATION_MS + 1) }),
  );
  assertEquals(long.ok, false);
  if (!long.ok) assertEquals(long.code, "audio_duration_too_long");
});

Deno.test("requires a UUID request id and a positive integer duration", () => {
  const missingID = validateSpeechTranscribeFormData(
    makeFormData({ clientRequestId: "not-a-uuid" }),
  );
  assertEquals(missingID.ok, false);
  if (!missingID.ok) assertEquals(missingID.code, "invalid_client_request_id");

  const invalidDuration = validateSpeechTranscribeFormData(
    makeFormData({ durationMs: "0.5" }),
  );
  assertEquals(invalidDuration.ok, false);
  if (!invalidDuration.ok) {
    assertEquals(invalidDuration.code, "invalid_duration");
  }
});

Deno.test("authenticates, claims capture capacity, and sends OpenAI multipart without a manual content type", async () => {
  const { deps, calls, fetchCalls } = fakeDependencies();
  const handler = createSpeechTranscribeHandler(deps);
  const response = await handler(makeRequest(makeFormData()));

  assertEquals(response.status, 200);
  assertEquals(await responseBody(response), {
    text: "I am tired today.",
    language: "zh",
    durationMs: 2500,
  });
  assertEquals(calls.find((call) => call.name === "claim_generation_request"), {
    name: "claim_generation_request",
    args: {
      p_user_id: USER_ID,
      p_operation_type: "speech_transcription",
      p_client_request_id: REQUEST_ID,
      p_minute_limit: 2,
      p_daily_limit: 10,
    },
  });
  assertEquals(calls.at(-1)?.name, "complete_generation_request");
  assertEquals(fetchCalls.length, 1);
  const providerRequest = fetchCalls[0];
  assertEquals(
    providerRequest.url,
    "https://api.openai.com/v1/audio/transcriptions",
  );
  assertEquals(
    providerRequest.headers.get("Authorization"),
    "Bearer test-openai-key",
  );
  assertEquals(
    providerRequest.headers.get("Content-Type")?.startsWith(
      "multipart/form-data",
    ),
    true,
  );
  const body = await providerRequest.formData();
  assertEquals(body.get("model"), SPEECH_TRANSCRIPTION_MODEL);
  assertEquals(body.get("language"), "zh");
  assertExists(body.get("file"));
});

Deno.test("returns an idempotent replay without calling OpenAI", async () => {
  const replayPayload = {
    text: "I am tired today.",
    language: "zh",
    durationMs: 2500,
  };
  const { deps, calls, fetchCalls } = fakeDependencies({
    claim: {
      decision: "replay",
      retryAfterSeconds: 0,
      responsePayload: replayPayload,
    },
  });
  const response = await createSpeechTranscribeHandler(deps)(
    makeRequest(makeFormData()),
  );

  assertEquals(response.status, 200);
  assertEquals(await responseBody(response), replayPayload);
  assertEquals(fetchCalls.length, 0);
  assertEquals(
    calls.filter((call) => call.name === "claim_generation_request").length,
    1,
  );
});

Deno.test("maps quota decisions to safe 429 errors and does not call OpenAI", async () => {
  const { deps, fetchCalls } = fakeDependencies({
    claim: {
      decision: "quota_exceeded",
      retryAfterSeconds: 60,
      responsePayload: null,
    },
  });
  const response = await createSpeechTranscribeHandler(deps)(
    makeRequest(makeFormData()),
  );
  assertEquals(response.status, 429);
  assertEquals(await responseBody(response), {
    error: "quota_exceeded",
    message: "Daily speech transcription quota exceeded",
    retryAfterSeconds: 60,
  });
  assertEquals(fetchCalls.length, 0);
});

Deno.test("fails the ledger and returns a safe provider error", async () => {
  const { deps, calls } = fakeDependencies({
    providerResponse: new Response("provider details", { status: 500 }),
  });
  const response = await createSpeechTranscribeHandler(deps)(
    makeRequest(makeFormData()),
  );
  assertEquals(response.status, 502);
  assertEquals(await responseBody(response), {
    error: "transcription_failed",
    message: "Speech transcription failed",
  });
  assertEquals(calls.at(-1)?.name, "fail_generation_request");
});

Deno.test("fails the ledger when the provider returns no transcript text", async () => {
  const { deps, calls } = fakeDependencies({
    providerResponse: Response.json({ text: "   " }),
  });
  const response = await createSpeechTranscribeHandler(deps)(
    makeRequest(makeFormData()),
  );
  assertEquals(response.status, 502);
  assertEquals(await responseBody(response), {
    error: "transcription_empty",
    message: "Speech transcription returned no text",
  });
  assertEquals(calls.at(-1)?.name, "fail_generation_request");
});

Deno.test("returns unauthorized before parsing multipart for unauthenticated requests", async () => {
  const { deps, fetchCalls } = fakeDependencies({
    auth: Response.json(
      { error: "unauthorized", message: "Unauthorized" },
      { status: 401 },
    ),
  });
  const response = await createSpeechTranscribeHandler(deps)(
    makeRequest(new FormData()),
  );
  assertEquals(response.status, 401);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("rejects malformed multipart requests without a provider or database call", async () => {
  const { deps, calls, fetchCalls } = fakeDependencies();
  const request = new Request(
    "https://example.test/functions/v1/speech-transcribe",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    },
  );
  const response = await createSpeechTranscribeHandler(deps)(request);
  assertEquals(response.status, 400);
  assertEquals(await responseBody(response), {
    error: "invalid_multipart",
    message: "Content-Type must be multipart/form-data",
  });
  assertEquals(calls.length, 0);
  assertEquals(fetchCalls.length, 0);
});

Deno.test("keeps the production listener behind import.meta.main", () => {
  assertStringIncludes(FUNCTION_SOURCE, "if (import.meta.main)");
  assertStringIncludes(
    FUNCTION_SOURCE,
    "Deno.serve(createSpeechTranscribeHandler())",
  );
});

Deno.test("claims the independent speech budget before calling OpenAI", () => {
  const claimIndex = FUNCTION_SOURCE.indexOf("claim_generation_request");
  const providerIndex = FUNCTION_SOURCE.indexOf(
    "https://api.openai.com/v1/audio/transcriptions",
  );
  assertEquals(claimIndex >= 0, true);
  assertEquals(providerIndex > claimIndex, true);
  assertStringIncludes(FUNCTION_SOURCE, "p_operation_type: OPERATION_TYPE");
  assertStringIncludes(FUNCTION_SOURCE, '"SPEECH_TRANSCRIPTION_MINUTE_LIMIT"');
  assertStringIncludes(FUNCTION_SOURCE, '"SPEECH_TRANSCRIPTION_DAILY_LIMIT"');
});
