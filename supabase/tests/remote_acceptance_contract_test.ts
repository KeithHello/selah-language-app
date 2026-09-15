import {
  assertEquals,
  assertNotEquals,
  assertRejects,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACCEPTANCE_PROVIDER_CALL_BUDGET,
  createRunPlan,
  dryRunSummary,
  loadExecuteConfig,
  parseOptions,
  runRemoteAcceptance,
  runRemoteAcceptanceCommand,
} from "../scripts/remote_acceptance.ts";

const SCRIPT_SOURCE = await Deno.readTextFile(
  "supabase/scripts/remote_acceptance.ts",
);

Deno.test("remote acceptance defaults to a non-network dry run", () => {
  assertEquals(parseOptions([]), { execute: false, help: false });
  assertEquals(parseOptions(["--help"]), { execute: false, help: true });
  assertEquals(
    dryRunSummary()[0],
    "DRY RUN ONLY: no Supabase, OpenAI, Storage, or auth request will be made.",
  );
});

Deno.test("dry-run command never invokes its fetch dependency", async () => {
  let fetchCalls = 0;
  let reads = 0;
  const result = await runRemoteAcceptanceCommand([], {}, {
    fetch: () => {
      fetchCalls += 1;
      throw new Error("dry-run must not fetch");
    },
    readAudioFile: () => {
      reads += 1;
      throw new Error("dry-run must not read a sample");
    },
  });

  assertEquals(result.status, "dry-run");
  assertEquals(fetchCalls, 0);
  assertEquals(reads, 0);
});

Deno.test("billable gate is checked before reading an execute-only audio sample", async () => {
  let reads = 0;
  await assertRejects(
    () =>
      runRemoteAcceptanceCommand(
        ["--execute", "--audio-file", "sample.wav"],
        {
          SUPABASE_URL: "https://example.supabase.co",
          SUPABASE_PUBLISHABLE_KEY: "publishable",
          SUPABASE_TEST_EMAIL: "primary@example.com",
          SUPABASE_TEST_PASSWORD: "password",
        },
        {
          readAudioFile: () => {
            reads += 1;
            return Promise.resolve(new Uint8Array([1]));
          },
        },
      ),
    Error,
    "REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true",
  );
  assertEquals(reads, 0);
});

Deno.test("run plans use fresh run IDs and stable request IDs for resume", () => {
  const first = createRunPlan();
  const second = createRunPlan();
  const resumed = createRunPlan(first.runId);

  assertNotEquals(first.runId, second.runId);
  assertEquals(resumed, first);
  assertEquals(
    Object.values(first.requestIds).every((value) =>
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(value)
    ),
    true,
  );
});

Deno.test("parseOptions accepts an explicit resume run and supplied audio file", () => {
  assertEquals(
    parseOptions([
      "--execute",
      "--resume",
      "run-123",
      "--audio-file=fixtures/capture=part.wav",
      "--audio-duration-ms",
      "2500",
    ]),
    {
      execute: true,
      help: false,
      resumeRunId: "run-123",
      audioFilePath: "fixtures/capture=part.wav",
      audioDurationMs: 2500,
    },
  );
});

Deno.test("parseOptions rejects missing option values instead of consuming the next flag", () => {
  assertThrows(
    () => parseOptions(["--resume", "--execute"]),
    Error,
    "requires a run ID",
  );
  assertThrows(
    () => parseOptions(["--audio-file", "--execute"]),
    Error,
    "requires a path",
  );
});

interface FakeRequestLog {
  kind: string;
  request: Request;
}

const PREPARED_SEGMENTS = [
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f21",
    orderIndex: 0,
    sourceText: "我今天有點累。",
  },
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f22",
    orderIndex: 1,
    sourceText: "但是我還是想完成今天的練習。",
  },
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f23",
    orderIndex: 2,
    sourceText: "第三段測試。",
  },
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f24",
    orderIndex: 3,
    sourceText: "第四段測試。",
  },
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f25",
    orderIndex: 4,
    sourceText: "第五段測試。",
  },
  {
    segmentId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f26",
    orderIndex: 5,
    sourceText: "第六段測試。",
  },
] as const;

function fakeRemoteFetch(
  log: FakeRequestLog[],
  prepareSegmentCount = 2,
): typeof fetch {
  return async (input: Request | URL | string, init?: RequestInit) => {
    const request = input instanceof Request ? input : new Request(input, init);
    const url = new URL(request.url);
    const kind = url.pathname.startsWith("/functions/v1/")
      ? url.pathname.slice("/functions/v1/".length)
      : url.pathname === "/auth/v1/token"
      ? "auth"
      : url.pathname === "/auth/v1/user"
      ? "auth-user"
      : url.pathname.startsWith("/rest/v1/")
      ? url.pathname.slice("/rest/v1/".length)
      : "signed-audio";
    log.push({ kind, request: request.clone() });

    if (kind === "auth") {
      const body = await request.json() as { email?: string };
      return Response.json({
        access_token: body.email?.includes("second")
          ? "ordinary-jwt-second"
          : "ordinary-jwt-primary",
      });
    }
    if (kind === "auth-user") {
      return Response.json({ id: "ordinary-user" });
    }
    if (kind === "config-bootstrap") {
      return Response.json({
        defaultVoiceProfile: "gentle-natural",
        voiceProfiles: ["gentle-natural", "clear", "warm", "calm"],
      });
    }
    if (kind === "speech-transcribe") {
      const form = await request.formData();
      if (!(form.get("file") instanceof File)) {
        return Response.json({ error: "missing_audio_file" }, { status: 400 });
      }
      return Response.json({
        text: "我今天有點累。",
        language: "zh-Hant",
        durationMs: 2500,
      });
    }
    if (kind === "sentences-generate") {
      return Response.json({
        targetText: "I am tired today.",
        category: "daily_life",
        vocabulary: [],
        deconstruction: [],
        promptVersion: "v8.0",
      });
    }
    if (kind === "sentences-prepare") {
      return Response.json({
        segments: PREPARED_SEGMENTS.slice(0, prepareSegmentCount),
      });
    }
    if (kind === "sentences-batch-generate") {
      const body = await request.json() as {
        segments?: Array<{ segmentId: string }>;
      };
      return Response.json({
        items: (body.segments ?? []).map((segment, index) => ({
          segmentId: segment.segmentId,
          targetText: index === 0
            ? "I am tired today."
            : "But I still want to finish today's practice.",
          category: "daily_life",
          vocabulary: [],
          deconstruction: [],
        })),
      });
    }
    if (kind === "audio-generate") {
      return Response.json({
        status: "ready",
        manifestId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f31",
        downloadUrl: "https://signed.example.test/audio/acceptance.mp3",
        cacheHit: log.filter((entry) => entry.kind === "audio-generate")
          .length > 1,
      });
    }
    if (kind === "audio-download-url") {
      return Response.json({
        status: "ready",
        manifestId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f31",
        downloadUrl: "https://signed.example.test/audio/acceptance.mp3",
        cacheHit: true,
      });
    }
    if (kind === "sentences" || kind === "learning_events") {
      if (
        request.headers.get("Authorization") === "Bearer ordinary-jwt-second"
      ) {
        return Response.json([]);
      }
      return Response.json([{ id: url.searchParams.get("id") }]);
    }
    if (kind === "audio_manifests") {
      if (
        request.headers.get("Authorization") === "Bearer ordinary-jwt-second"
      ) {
        return Response.json([]);
      }
      return Response.json([{ id: url.searchParams.get("id") }]);
    }
    if (kind === "signed-audio") {
      return new Response(new Uint8Array(1024), { status: 200 });
    }
    throw new Error(`unexpected fake endpoint: ${kind}`);
  };
}

function testConfig(): {
  supabaseURL: string;
  publishableKey: string;
  email: string;
  password: string;
} {
  return {
    supabaseURL: "https://example.supabase.co",
    publishableKey: "publishable",
    email: "primary@example.com",
    password: "password",
  };
}

Deno.test("runner uses the supplied recording and bounds requests to one submission plus one replay per step", async () => {
  const log: FakeRequestLog[] = [];
  const result = await runRemoteAcceptance(
    testConfig(),
    fakeRemoteFetch(log),
    {
      runId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f11",
      audioFile: new File([new Uint8Array([1, 2, 3])], "sample.wav", {
        type: "audio/wav",
      }),
      audioDurationMs: 2500,
    },
  );

  assertEquals(result.status, "passed");
  assertEquals(result.segmentCount, 2);
  assertEquals(result.providerCallBudget, ACCEPTANCE_PROVIDER_CALL_BUDGET);
  assertEquals(result.requestCounts, {
    "config-bootstrap": 1,
    "speech-transcribe": 2,
    "sentences-generate": 2,
    "sentences-prepare": 2,
    "sentences-batch-generate": 2,
    "audio-generate": 2,
    "audio-download-url": 1,
    "audio-download": 1,
  });

  const speechRequests = log.filter((entry) =>
    entry.kind === "speech-transcribe"
  );
  assertEquals(speechRequests.length, 2);
  const firstSpeechForm = await speechRequests[0].request.formData();
  const replaySpeechForm = await speechRequests[1].request.formData();
  assertEquals((firstSpeechForm.get("file") as File).type, "audio/wav");
  assertEquals(firstSpeechForm.get("durationMs"), "2500");
  assertEquals(
    replaySpeechForm.get("clientRequestId"),
    firstSpeechForm.get("clientRequestId"),
  );
  const sentenceRequests = log.filter((entry) =>
    entry.kind === "sentences-generate"
  );
  const firstSentenceBody = await sentenceRequests[0].request.clone()
    .json() as {
      clientRequestId: string;
    };
  const replaySentenceBody = await sentenceRequests[1].request.clone()
    .json() as {
      clientRequestId: string;
    };
  assertEquals(
    replaySentenceBody.clientRequestId,
    firstSentenceBody.clientRequestId,
  );
  const preparationRequests = log.filter((entry) =>
    entry.kind === "sentences-prepare"
  );
  const firstPreparationBody = await preparationRequests[0].request.clone()
    .json() as {
      clientRequestId: string;
    };
  const replayPreparationBody = await preparationRequests[1].request.clone()
    .json() as {
      clientRequestId: string;
    };
  assertEquals(
    replayPreparationBody.clientRequestId,
    firstPreparationBody.clientRequestId,
  );
  const batchBodies = log.filter((entry) =>
    entry.kind === "sentences-batch-generate"
  );
  assertEquals(batchBodies.length, 2);
  const batchBody = await batchBodies[0].request.clone().json() as {
    clientRequestId: string;
    segments: unknown[];
  };
  const replayBatchBody = await batchBodies[1].request.clone().json() as {
    clientRequestId: string;
  };
  assertEquals(batchBody.segments.length <= 5, true);
  assertEquals(replayBatchBody.clientRequestId, batchBody.clientRequestId);
  const audioBodies = log.filter((entry) => entry.kind === "audio-generate");
  const firstAudioBody = await audioBodies[0].request.clone().json() as {
    clientRequestId: string;
    sentenceId: string;
  };
  const replayAudioBody = await audioBodies[1].request.clone().json() as {
    clientRequestId: string;
    sentenceId: string;
  };
  assertEquals(replayAudioBody.clientRequestId, firstAudioBody.clientRequestId);
  assertEquals(replayAudioBody.sentenceId, firstAudioBody.sentenceId);
});

Deno.test("runner stops before batch calls when preparation exceeds five segments", async () => {
  const log: FakeRequestLog[] = [];
  await assertRejects(
    () =>
      runRemoteAcceptance(
        testConfig(),
        fakeRemoteFetch(log, 6),
        {
          runId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f14",
          audioFile: new File([new Uint8Array([1, 2, 3])], "sample.wav", {
            type: "audio/wav",
          }),
        },
      ),
    Error,
    "more than five segments",
  );
  assertEquals(
    log.some((entry) => entry.kind === "sentences-batch-generate"),
    false,
  );
});

Deno.test("runner requires an explicitly supplied audio sample before any network request", async () => {
  let fetchCalls = 0;
  await assertRejects(
    () =>
      runRemoteAcceptance(testConfig(), () => {
        fetchCalls += 1;
        throw new Error("should not fetch");
      }, { runId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f12" }),
    Error,
    "audio sample file is required",
  );
  assertEquals(fetchCalls, 0);
});

Deno.test("execute failures include the resumable run ID", async () => {
  await assertRejects(
    () =>
      runRemoteAcceptanceCommand(
        [
          "--execute",
          "--resume",
          "resume-run-123",
          "--audio-file",
          "sample.wav",
        ],
        {
          REMOTE_ACCEPTANCE_ALLOW_BILLABLE: "true",
          SUPABASE_URL: "https://example.supabase.co",
          SUPABASE_PUBLISHABLE_KEY: "publishable",
          SUPABASE_TEST_EMAIL: "primary@example.com",
          SUPABASE_TEST_PASSWORD: "password",
        },
        {
          readAudioFile: () => Promise.resolve(new Uint8Array([1, 2, 3])),
          fetch: () => Promise.reject(new Error("network disabled in test")),
        },
      ),
    Error,
    "remote acceptance run resume-run-123 failed; retry with --resume resume-run-123",
  );
});

for (
  const scenario of [
    "missing-secondary-account",
    "invalid-secondary-login",
    "missing-sentence-fixture",
    "missing-event-fixture",
    "visible-sentence-fixture",
    "visible-event-fixture",
  ]
) {
  Deno.test(`RLS preflight blocks paid endpoints for ${scenario}`, async () => {
    const log: FakeRequestLog[] = [];
    const normalFetch = fakeRemoteFetch(log);
    let paidRequests = 0;
    const interceptedFetch: typeof fetch = async (input, init) => {
      const request = input instanceof Request
        ? input
        : new Request(input, init);
      const pathname = new URL(request.url).pathname;
      if (
        /\/functions\/v1\/(speech-transcribe|sentences-|audio-generate)/.test(
          pathname,
        )
      ) {
        paidRequests += 1;
      }
      if (
        scenario === "invalid-secondary-login" &&
        pathname === "/auth/v1/token" &&
        (await request.clone().json()).email === "second@example.com"
      ) {
        return Response.json({ error: "invalid_credentials" }, { status: 400 });
      }
      const table = scenario.includes("sentence")
        ? "sentences"
        : "learning_events";
      const secondary = request.headers.get("Authorization") ===
        "Bearer ordinary-jwt-second";
      if (pathname === `/rest/v1/${table}`) {
        if (scenario.startsWith("missing-") && !secondary) {
          return Response.json([]);
        }
        if (scenario.startsWith("visible-") && secondary) {
          return Response.json([{ id: "foreign-fixture" }]);
        }
      }
      return normalFetch(request);
    };

    await assertRejects(
      () =>
        runRemoteAcceptance(
          {
            ...testConfig(),
            ...(scenario === "missing-secondary-account" ? {} : {
              secondaryEmail: "second@example.com",
              secondaryPassword: "password-2",
            }),
            rlsSentenceId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f41",
            rlsEventId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f42",
          },
          interceptedFetch,
          {
            audioFile: new File([new Uint8Array([1, 2, 3])], "sample.wav", {
              type: "audio/wav",
            }),
          },
        ),
      Error,
      scenario === "missing-secondary-account"
        ? "requires a configured secondary test account"
        : scenario === "invalid-secondary-login"
        ? "test account sign-in failed"
        : scenario.startsWith("missing-")
        ? "not visible to primary account"
        : "secondary account can read",
    );
    assertEquals(paidRequests, 0);
  });
}

Deno.test("runner checks accounts and existing RLS fixtures before paying, then checks the new audio manifest", async () => {
  const log: FakeRequestLog[] = [];
  const result = await runRemoteAcceptance(
    {
      ...testConfig(),
      secondaryEmail: "second@example.com",
      secondaryPassword: "password-2",
      rlsSentenceId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f41",
      rlsEventId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f42",
    },
    fakeRemoteFetch(log),
    {
      runId: "6f94f4f4-1c0d-4b9b-a42d-1a3b9b1f0f13",
      audioFile: new File([new Uint8Array([1, 2, 3])], "sample.wav", {
        type: "audio/wav",
      }),
    },
  );

  assertEquals(
    (result.rls as { secondaryAccount: string }).secondaryAccount,
    "isolated",
  );
  assertEquals(
    (result.rls as { sentenceFixture: string }).sentenceFixture,
    "isolated",
  );
  assertEquals(
    (result.rls as { eventFixture: string }).eventFixture,
    "isolated",
  );
  const firstPaidRequest = log.findIndex((entry) =>
    entry.kind === "speech-transcribe"
  );
  const preflightRequests = log.slice(0, firstPaidRequest);
  assertEquals(
    preflightRequests.filter((entry) => entry.kind === "auth").length,
    2,
  );
  assertEquals(
    preflightRequests.filter((entry) => entry.kind === "sentences").length,
    2,
  );
  assertEquals(
    preflightRequests.filter((entry) => entry.kind === "learning_events")
      .length,
    2,
  );
  assertEquals(log.filter((entry) => entry.kind === "auth").length, 2);
  assertEquals(
    log.filter((entry) => entry.kind === "audio_manifests").length,
    2,
  );
  assertEquals(JSON.stringify(result).includes("ordinary-jwt-"), false);
});

Deno.test("execute mode requires an explicit billable approval", () => {
  assertThrows(
    () =>
      loadExecuteConfig({
        SUPABASE_URL: "https://example.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "publishable",
        SUPABASE_TEST_EMAIL: "test@example.com",
        SUPABASE_TEST_PASSWORD: "password",
      }),
    Error,
    "REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true",
  );
});

Deno.test("execute mode requires only test-account configuration", () => {
  assertEquals(
    loadExecuteConfig({
      REMOTE_ACCEPTANCE_ALLOW_BILLABLE: "true",
      SUPABASE_URL: "https://example.supabase.co/",
      SUPABASE_PUBLISHABLE_KEY: "publishable",
      SUPABASE_TEST_EMAIL: "test@example.com",
      SUPABASE_TEST_PASSWORD: "password",
    }),
    {
      supabaseURL: "https://example.supabase.co",
      publishableKey: "publishable",
      email: "test@example.com",
      password: "password",
    },
  );
});

Deno.test("optional RLS checks accept a second ordinary test account without service-role credentials", () => {
  const config = loadExecuteConfig({
    REMOTE_ACCEPTANCE_ALLOW_BILLABLE: "true",
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_PUBLISHABLE_KEY: "publishable",
    SUPABASE_TEST_EMAIL: "primary@example.com",
    SUPABASE_TEST_PASSWORD: "password",
    SUPABASE_TEST_EMAIL_2: "second@example.com",
    SUPABASE_TEST_PASSWORD_2: "password-2",
  });

  assertEquals(config.secondaryEmail, "second@example.com");
  assertEquals(config.secondaryPassword, "password-2");
  assertEquals("SUPABASE_SERVICE_ROLE_KEY" in config, false);
});

Deno.test("runner covers the complete remote acceptance matrix", () => {
  for (
    const endpoint of [
      "config-bootstrap",
      "speech-transcribe",
      "sentences-generate",
      "sentences-prepare",
      "sentences-batch-generate",
      "audio-generate",
      "audio-download-url",
    ]
  ) {
    assertStringIncludes(SCRIPT_SOURCE, endpoint);
  }
  assertStringIncludes(SCRIPT_SOURCE, "sentence-generation-replay");
  assertStringIncludes(SCRIPT_SOURCE, "capture-preparation-replay");
  assertStringIncludes(SCRIPT_SOURCE, "REMOTE_ACCEPTANCE_ALLOW_BILLABLE");
});

Deno.test("runner does not print credentials or raw transcript content", () => {
  assertEquals(SCRIPT_SOURCE.includes("console.log(config"), false);
  assertEquals(SCRIPT_SOURCE.includes("console.log(accessToken"), false);
  assertEquals(SCRIPT_SOURCE.includes("console.log(TEST_TRANSCRIPT"), false);
  assertEquals(SCRIPT_SOURCE.includes("Deno.env.toObject"), false);
  assertEquals(SCRIPT_SOURCE.includes("SUPABASE_SERVICE_ROLE_KEY"), false);
});
