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
import { azureBillableCharacterCount } from "../functions/_shared/azure_speech.ts";

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

Deno.test("routes Japanese source audio to Azure Nanami in Japanese locale", () => {
  const result = resolveAudioRoute({
    audioRole: "source",
    sourceLanguage: "ja",
    targetLanguage: "en",
    accent: "ja-JP",
    voiceProfile: "native-gentle",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.route.provider, "azure");
  assertEquals(result.route.providerVoice, "ja-JP-NanamiNeural@native-gentle");
  assertEquals(result.route.accent, "ja-JP");
});

Deno.test("routes US English target audio to Azure Jenny", () => {
  const result = resolveAudioRoute({
    audioRole: "target",
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-US",
    voiceProfile: "gentle-natural",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.route.provider, "azure");
  assertEquals(result.route.providerVoice, "en-US-JennyNeural@gentle-natural");
  assertEquals(result.route.providerModel, "azure-speech/en-US-JennyNeural");
});

Deno.test("routes British English target audio to Azure Sonia", () => {
  const result = resolveAudioRoute({
    audioRole: "target",
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-GB",
    voiceProfile: "elegant-british",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.route.provider, "azure");
  assertEquals(result.route.providerVoice, "en-GB-SoniaNeural@elegant-british");
  assertEquals(result.route.accent, "en-GB");
});

Deno.test("maps target profiles to Azure voices and prosody speed", () => {
  const clear = resolveAudioRoute({
    audioRole: "target",
    targetLanguage: "en",
    voiceProfile: "clear-slow",
  });
  const bright = resolveAudioRoute({
    audioRole: "target",
    targetLanguage: "en",
    voiceProfile: "daily-bright",
  });
  assertEquals(clear.ok, true);
  assertEquals(bright.ok, true);
  if (!clear.ok || !bright.ok) return;
  assertEquals(clear.route.providerVoice, "en-US-JennyNeural@clear-slow");
  assertEquals(clear.route.speed, 0.9);
  assertEquals(bright.route.providerVoice, "en-US-GuyNeural@daily-bright");
  assertEquals(bright.route.speed, 1.05);
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
    `azure:zh-TW-HsiaoChenNeural@native-gentle:1:lufs-v1:${"a".repeat(64)}`,
  );
});

Deno.test("Azure SSML escapes text and carries the native prosody profile", () => {
  const result = resolveAudioRoute(BASE);
  assertEquals(result.ok, true);
  if (!result.ok) return;
  const ssml = buildAzureSsml("你好 <朋友>", result.route);
  assertStringIncludes(ssml, "zh-TW-HsiaoChenNeural");
  assertStringIncludes(ssml, 'xml:lang="zh-TW"');
  assertStringIncludes(ssml, "你好 &lt;朋友&gt;");
  assertStringIncludes(ssml, "prosody");
});

Deno.test("builds English and Japanese SSML with their matching locale", () => {
  const japanese = resolveAudioRoute({
    audioRole: "source",
    sourceLanguage: "ja",
    targetLanguage: "en",
    voiceProfile: "native-gentle",
  });
  const english = resolveAudioRoute({
    audioRole: "target",
    targetLanguage: "en",
    voiceProfile: "gentle-natural",
  });
  assertEquals(japanese.ok, true);
  assertEquals(english.ok, true);
  if (!japanese.ok || !english.ok) return;
  assertStringIncludes(
    buildAzureSsml("おはよう", japanese.route),
    'xml:lang="ja-JP"',
  );
  assertStringIncludes(
    buildAzureSsml("Good morning", english.route),
    'xml:lang="en-US"',
  );
});

Deno.test("Azure billable character count doubles Han and includes prosody markup", () => {
  const result = resolveAudioRoute(BASE);
  assertEquals(result.ok, true);
  if (!result.ok) return;
  const oneHan = azureBillableCharacterCount("漢", result.route);
  const oneLatin = azureBillableCharacterCount("a", result.route);
  assertEquals(oneHan - oneLatin, 1);
  assertEquals(azureBillableCharacterCount("", result.route) > 0, true);
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
