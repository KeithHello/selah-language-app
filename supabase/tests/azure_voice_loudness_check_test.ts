import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertBillableCharacterCap,
  BILLABLE_CHARACTER_CAP,
  buildLoudnessCheckWorkItems,
  buildNativeEnglishListeningPairs,
  estimateBillableCharacters,
  suggestSsmlVolume,
  summarizeMeasurements,
  TARGET_LUFS,
} from "../scripts/azure_voice_loudness_check.ts";

const seeds = Array.from({ length: 10 }, (_, index) => ({
  id: `seed-${index + 1}`,
  en_translation: "A quiet morning.",
  zh_text: "今天早上很安靜。",
  ja_text: "今朝は静かです。",
}));

Deno.test("loudness request plan covers twelve profiles and five same seeds", () => {
  const items = buildLoudnessCheckWorkItems(seeds);
  assertEquals(items.length, 60);
  assertEquals(new Set(items.map((item) => item.voiceId)).size, 12);
  assertEquals(new Set(items.map((item) => item.seedId)).size, 5);
  assertEquals(
    items.filter((item) => item.route.providerVoice.startsWith("ja-JP-"))
      .length,
    20,
  );
});

Deno.test("dry-run billing uses the final canonical SSML and raw billing omits volume", () => {
  const items = buildLoudnessCheckWorkItems(seeds);
  const withVolume = estimateBillableCharacters(items);
  const raw = estimateBillableCharacters(items, false);
  assertEquals(withVolume > raw, true);
  assertEquals(withVolume <= BILLABLE_CHARACTER_CAP, true);
  assertBillableCharacterCap(BILLABLE_CHARACTER_CAP);
  assertThrows(() => assertBillableCharacterCap(BILLABLE_CHARACTER_CAP + 1));
});

Deno.test("volume suggestions can raise or lower while respecting the peak ceiling", () => {
  assertEquals(TARGET_LUFS, -20.4);
  assertEquals(suggestSsmlVolume(-17.15, -4), "-31%");
  assertEquals(suggestSsmlVolume(-19.72, -2), "-8%");
  assertEquals(suggestSsmlVolume(-18.96, -4), "-15%");
  assertEquals(suggestSsmlVolume(-20.86, -3), "+5%");
  assertEquals(suggestSsmlVolume(-21, -2), "+7%");
  assertEquals(suggestSsmlVolume(-21, -1.5), "+5%");
  assertEquals(suggestSsmlVolume(-22, -1.2), "+2%");
  assertEquals(suggestSsmlVolume(-21, -0.8), "-3%");
  assertEquals(suggestSsmlVolume(-20.4, -1.5), null);
  assertThrows(() => suggestSsmlVolume(-21, Number.NaN));
});

Deno.test("voice summary reports mean, target deviation, peak and current gain", () => {
  const rows = [-21.1, -20.9].map((integratedLufs, index) => ({
    voiceId: "jenny-en-gentle",
    seedId: `seed-${index}`,
    providerVoice: "en-US-JennyNeural@gentle-natural",
    voiceProfile: "gentle-natural",
    billableCharacters: 20,
    integratedLufs,
    truePeakDbtp: -2 + index * 0.1,
    sha256: "a".repeat(64),
    path: `audio/sample-${index}.mp3`,
  }));
  const [summary] = summarizeMeasurements(rows);
  assertEquals(summary.count, 2);
  assertEquals(summary.averageLufs, -21);
  assertEquals(Math.round(summary.deviationFromTargetLufs * 100), -60);
  assertEquals(Math.round(summary.maxTruePeakDbtp * 10), -19);
  assertEquals(summary.currentVolume, "+6%");
  assertEquals(summary.suggestedVolume, "+7%");
});

Deno.test("native-English listening pairs alternate the same seed in request order", () => {
  const row = (voiceId: string, seedId: string, path: string) => ({
    voiceId,
    seedId,
    providerVoice: `${voiceId}-Neural`,
    voiceProfile: "native-gentle",
    billableCharacters: 20,
    integratedLufs: -20.4,
    truePeakDbtp: -1.5,
    sha256: "a".repeat(64),
    path,
  });
  const measurements = ["seed-1", "seed-2"].flatMap((seedId) => [
    row("hsiaochen-zh-gentle", seedId, `audio/zh-${seedId}.mp3`),
    row("jenny-en-gentle", seedId, `audio/en-${seedId}.mp3`),
  ]);
  assertEquals(
    buildNativeEnglishListeningPairs(measurements, "hsiaochen-zh-gentle"),
    [
      {
        seedId: "seed-1",
        nativePath: "audio/zh-seed-1.mp3",
        englishPath: "audio/en-seed-1.mp3",
      },
      {
        seedId: "seed-2",
        nativePath: "audio/zh-seed-2.mp3",
        englishPath: "audio/en-seed-2.mp3",
      },
    ],
  );
});
