import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  audioCacheKey,
  buildAzureSsml,
  resolveAudioRoute,
} from "../functions/_shared/audio_routing.ts";
import { shouldRetryProviderResponse } from "../functions/_shared/audio_generation_policy.ts";

const BASE = {
  audioRole: "source" as const,
  sourceLanguage: "zh-Hant",
  targetLanguage: "en",
  voiceProfile: "native-gentle",
};

Deno.test("routes traditional Chinese source audio to Azure Taiwan Mandarin", () => {
  const result = resolveAudioRoute(BASE);
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.route.provider, "azure");
  assertEquals(result.route.accent, "zh-TW");
  assertEquals(
    result.route.providerVoice,
    "zh-TW-HsiaoChenNeural@native-gentle",
  );
  assertEquals(
    result.route.providerModel,
    "azure-speech/zh-TW-HsiaoChenNeural",
  );
});

Deno.test("routes British English target audio to OpenAI British voice", () => {
  const result = resolveAudioRoute({
    audioRole: "target",
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-GB",
    voiceProfile: "elegant-british",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.route.provider, "openai");
  assertEquals(result.route.providerVoice, "shimmer");
  assertEquals(result.route.accent, "en-GB");
});

Deno.test("rejects an ambiguous request without an explicit audio role", () => {
  const result = resolveAudioRoute({
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    voiceProfile: "gentle-natural",
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "missing_audio_role");
});

Deno.test("rejects an accent that does not match the selected English voice", () => {
  const result = resolveAudioRoute({
    audioRole: "target",
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-US",
    voiceProfile: "elegant-british",
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "accent_voice_mismatch");
});

Deno.test("cache key includes provider, provider voice, speed and text hash", () => {
  assertEquals(
    audioCacheKey({
      provider: "azure",
      providerVoice: "zh-TW-HsiaoChenNeural@native-gentle",
      speed: 1,
      textHash: "a".repeat(64),
    }),
    `azure:zh-TW-HsiaoChenNeural@native-gentle:1:${"a".repeat(64)}`,
  );
});

Deno.test("Azure SSML escapes text and carries the native prosody profile", () => {
  const result = resolveAudioRoute(BASE);
  assertEquals(result.ok, true);
  if (!result.ok) return;
  const ssml = buildAzureSsml("你好 <朋友>", result.route);
  assertStringIncludes(ssml, "zh-TW-HsiaoChenNeural");
  assertStringIncludes(ssml, "你好 &lt;朋友&gt;");
  assertStringIncludes(ssml, "prosody");
});

Deno.test("provider retry policy retries timeouts, throttling and server errors only", () => {
  assertEquals(shouldRetryProviderResponse(null), true);
  assertEquals(shouldRetryProviderResponse(408), true);
  assertEquals(shouldRetryProviderResponse(429), true);
  assertEquals(shouldRetryProviderResponse(503), true);
  assertEquals(shouldRetryProviderResponse(400), false);
  assertEquals(shouldRetryProviderResponse(401), false);
  assertEquals(shouldRetryProviderResponse(404), false);
});
