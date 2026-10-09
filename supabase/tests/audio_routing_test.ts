import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  audioCacheKey,
  AZURE_VOICE_VOLUME,
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
    `azure:zh-TW-HsiaoChenNeural@native-gentle:1:azure-vol-v1:${
      "a".repeat(64)
    }`,
  );
});

Deno.test("Azure SSML applies the complete calibrated volume table by voice", () => {
  const cases = [
    {
      input: {
        audioRole: "target" as const,
        targetLanguage: "en",
        voiceProfile: "gentle-natural",
      },
      expected:
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US"><voice name="en-US-JennyNeural" xml:lang="en-US">Hello &amp; welcome</voice></speak>',
    },
    {
      input: {
        audioRole: "target" as const,
        targetLanguage: "en",
        voiceProfile: "clear-slow",
      },
      expected:
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US"><voice name="en-US-JennyNeural" xml:lang="en-US"><prosody rate="-10%">Hello &amp; welcome</prosody></voice></speak>',
    },
    {
      input: {
        audioRole: "target" as const,
        targetLanguage: "en",
        voiceProfile: "daily-bright",
      },
      expected:
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US"><voice name="en-US-GuyNeural" xml:lang="en-US"><prosody rate="+5%" pitch="+1st" volume="-13%">Hello &amp; welcome</prosody></voice></speak>',
    },
    {
      input: {
        audioRole: "target" as const,
        targetLanguage: "en",
        accent: "en-GB",
        voiceProfile: "elegant-british",
      },
      expected:
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-GB"><voice name="en-GB-SoniaNeural" xml:lang="en-GB"><prosody volume="-20%">Hello &amp; welcome</prosody></voice></speak>',
    },
  ];
  for (const { input, expected } of cases) {
    const result = resolveAudioRoute(input);
    assertEquals(result.ok, true);
    if (result.ok) {
      assertEquals(buildAzureSsml("Hello & welcome", result.route), expected);
    }
  }

  for (
    const [language, locale, voice, volume] of [
      ["zh-Hant", "zh-TW", "zh-TW-HsiaoChenNeural", "-19%"],
      ["ja", "ja-JP", "ja-JP-NanamiNeural", "-35%"],
    ] as const
  ) {
    for (
      const [profile, prosody] of [
        ["native-gentle", `volume="${volume}"`],
        ["native-clear", `rate="-5%" volume="${volume}"`],
        ["native-bright", `rate="+5%" pitch="+1st" volume="${volume}"`],
        ["native-calm", `rate="-8%" pitch="-1st" volume="${volume}"`],
      ] as const
    ) {
      const result = resolveAudioRoute({
        audioRole: "source",
        sourceLanguage: language,
        targetLanguage: "en",
        voiceProfile: profile,
      });
      assertEquals(result.ok, true);
      if (!result.ok) continue;
      assertEquals(
        buildAzureSsml("早安", result.route),
        `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="${locale}"><voice name="${voice}" xml:lang="${locale}"><prosody ${prosody}>早安</prosody></voice></speak>`,
      );
    }
  }
});

Deno.test("Azure SSML escapes text and billing follows the canonical markup", () => {
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
  const japaneseSsml = buildAzureSsml("おはよう <友達>", japanese.route);
  assertStringIncludes(japaneseSsml, 'xml:lang="ja-JP"');
  assertStringIncludes(japaneseSsml, "おはよう &lt;友達&gt;");
  const englishCharacters = azureBillableCharacterCount("hello", english.route);
  assertEquals(englishCharacters, 5);
  assertEquals(azureBillableCharacterCount("漢", japanese.route) > 2, true);
  const rawSsml = buildAzureSsml("おはよう", japanese.route, {
    applyVolume: false,
  });
  assertEquals(rawSsml.includes('volume="-35%"'), false);
  assertEquals(AZURE_VOICE_VOLUME["ja-JP-NanamiNeural"], "-35%");
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
