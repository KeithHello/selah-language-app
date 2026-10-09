#!/usr/bin/env -S deno run --allow-net --allow-read=. --allow-write=output --allow-run=ffmpeg --allow-env=AZURE_SPEECH_KEY,AZURE_SPEECH_REGION
/**
 * Check Azure voice loudness for ten starter sentences across five voices.
 * Dry-run is the default. Paid synthesis requires both --execute and
 * --cost-approved and is capped at 6,000 Azure billable characters.
 */

import { AUDIO_LEVEL_REVISION, sha256 } from "../functions/_shared/audio.ts";
import {
  type AudioRoute,
  AZURE_VOICE_VOLUME,
  resolveAudioRoute,
} from "../functions/_shared/audio_routing.ts";
import {
  azureBillableCharacterCount,
  buildAzureSpeechRequest,
} from "../functions/_shared/azure_speech.ts";
import { isLikelyMp3Audio } from "../functions/_shared/audio_generation_policy.ts";

export const TARGET_LUFS = -20.4;
export const BILLABLE_CHARACTER_CAP = 6_000;

const VOICE_CHECKS = [
  {
    voiceId: "jenny-en-gentle",
    audioRole: "target" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-US",
    voiceProfile: "gentle-natural",
    textField: "en_translation",
  },
  {
    voiceId: "jenny-en-clear",
    audioRole: "target" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-US",
    voiceProfile: "clear-slow",
    textField: "en_translation",
  },
  {
    voiceId: "guy-en-bright",
    audioRole: "target" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-US",
    voiceProfile: "daily-bright",
    textField: "en_translation",
  },
  {
    voiceId: "sonia-en-british",
    audioRole: "target" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "en-GB",
    voiceProfile: "elegant-british",
    textField: "en_translation",
  },
  {
    voiceId: "hsiaochen-zh-gentle",
    audioRole: "source" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "zh-TW",
    voiceProfile: "native-gentle",
    textField: "zh_text",
  },
  {
    voiceId: "hsiaochen-zh-clear",
    audioRole: "source" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "zh-TW",
    voiceProfile: "native-clear",
    textField: "zh_text",
  },
  {
    voiceId: "hsiaochen-zh-bright",
    audioRole: "source" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "zh-TW",
    voiceProfile: "native-bright",
    textField: "zh_text",
  },
  {
    voiceId: "hsiaochen-zh-calm",
    audioRole: "source" as const,
    sourceLanguage: "zh-Hant",
    targetLanguage: "en",
    accent: "zh-TW",
    voiceProfile: "native-calm",
    textField: "zh_text",
  },
  {
    voiceId: "nanami-ja-gentle",
    audioRole: "source" as const,
    sourceLanguage: "ja",
    targetLanguage: "en",
    accent: "ja-JP",
    voiceProfile: "native-gentle",
    textField: "ja_text",
  },
  {
    voiceId: "nanami-ja-clear",
    audioRole: "source" as const,
    sourceLanguage: "ja",
    targetLanguage: "en",
    accent: "ja-JP",
    voiceProfile: "native-clear",
    textField: "ja_text",
  },
  {
    voiceId: "nanami-ja-bright",
    audioRole: "source" as const,
    sourceLanguage: "ja",
    targetLanguage: "en",
    accent: "ja-JP",
    voiceProfile: "native-bright",
    textField: "ja_text",
  },
  {
    voiceId: "nanami-ja-calm",
    audioRole: "source" as const,
    sourceLanguage: "ja",
    targetLanguage: "en",
    accent: "ja-JP",
    voiceProfile: "native-calm",
    textField: "ja_text",
  },
] as const;

export interface SeedSentence {
  id: string;
  en_translation?: string;
  zh_text?: string;
  ja_text?: string;
}

export interface LoudnessCheckWorkItem {
  voiceId: string;
  seedId: string;
  text: string;
  voiceProfile: string;
  route: AudioRoute;
}

export interface VoiceMeasurement {
  voiceId: string;
  seedId: string;
  providerVoice: string;
  voiceProfile: string;
  billableCharacters: number;
  integratedLufs: number;
  truePeakDbtp: number;
  sha256: string;
  path: string;
}

export interface VoiceSummary {
  voiceId: string;
  providerVoice: string;
  voiceProfile: string;
  count: number;
  averageLufs: number;
  deviationFromTargetLufs: number;
  maxTruePeakDbtp: number;
  currentVolume: string | null;
  suggestedVolume: string | null;
}

export interface ListeningPair {
  seedId: string;
  nativePath: string;
  englishPath: string;
}

export function buildLoudnessCheckWorkItems(
  seeds: readonly SeedSentence[],
): LoudnessCheckWorkItem[] {
  if (seeds.length < 5) {
    throw new RangeError("At least five starter seed sentences are required");
  }
  const items: LoudnessCheckWorkItem[] = [];
  for (const seed of seeds.slice(0, 5)) {
    if (!seed.id) throw new Error("Every seed sentence requires an id");
    for (const check of VOICE_CHECKS) {
      const text = seed[check.textField]?.trim();
      if (!text) {
        throw new Error(`Seed ${seed.id} is missing ${check.textField}`);
      }
      const resolved = resolveAudioRoute({
        audioRole: check.audioRole,
        sourceLanguage: check.sourceLanguage,
        targetLanguage: check.targetLanguage,
        accent: check.accent,
        voiceProfile: check.voiceProfile,
      });
      if (!resolved.ok) throw new Error(resolved.message);
      items.push({
        voiceId: check.voiceId,
        seedId: seed.id,
        text,
        voiceProfile: check.voiceProfile,
        route: resolved.route,
      });
    }
  }
  return items;
}

export function estimateBillableCharacters(
  items: readonly LoudnessCheckWorkItem[],
  applyVolume = true,
): number {
  return items.reduce(
    (total, item) =>
      total +
      azureBillableCharacterCount(item.text, item.route, { applyVolume }),
    0,
  );
}

export function assertBillableCharacterCap(
  characters: number,
  cap = BILLABLE_CHARACTER_CAP,
): void {
  if (
    !Number.isSafeInteger(characters) || characters < 0 ||
    !Number.isSafeInteger(cap) || cap < 1 || characters > cap
  ) {
    throw new RangeError(
      `Azure billable character estimate ${characters} exceeds cap ${cap}`,
    );
  }
}

export function suggestSsmlVolume(
  measuredAverageLufs: number,
  maxTruePeakDbtp: number,
  targetLufs = TARGET_LUFS,
): string | null {
  if (
    !Number.isFinite(measuredAverageLufs) ||
    !Number.isFinite(maxTruePeakDbtp) ||
    !Number.isFinite(targetLufs)
  ) {
    throw new RangeError("LUFS and true-peak values must be finite");
  }
  const desiredGainDb = targetLufs - measuredAverageLufs;
  const peakLimitedGainDb = -1 - maxTruePeakDbtp;
  const gainDb = Math.min(desiredGainDb, peakLimitedGainDb);
  let percent = Math.min(
    100,
    Math.max(-100, Math.round((10 ** (gainDb / 20) - 1) * 100)),
  );
  while (
    percent > -100 &&
    maxTruePeakDbtp + 20 * Math.log10(1 + percent / 100) > -1
  ) {
    percent -= 1;
  }
  return percent === 0 ? null : `${percent > 0 ? "+" : ""}${percent}%`;
}

export function summarizeMeasurements(
  measurements: readonly VoiceMeasurement[],
  targetLufs = TARGET_LUFS,
): VoiceSummary[] {
  const groups = new Map<string, VoiceMeasurement[]>();
  for (const measurement of measurements) {
    const rows = groups.get(measurement.voiceId) ?? [];
    rows.push(measurement);
    groups.set(measurement.voiceId, rows);
  }
  return [...groups.entries()].map(([voiceId, rows]) => {
    if (rows.length === 0) throw new Error(`No measurements for ${voiceId}`);
    const averageLufs = rows.reduce((sum, row) => sum + row.integratedLufs, 0) /
      rows.length;
    const voice = rows[0].providerVoice.split("@", 1)[0];
    return {
      voiceId,
      providerVoice: rows[0].providerVoice,
      voiceProfile: rows[0].voiceProfile,
      count: rows.length,
      averageLufs,
      deviationFromTargetLufs: averageLufs - targetLufs,
      maxTruePeakDbtp: Math.max(...rows.map((row) => row.truePeakDbtp)),
      currentVolume: AZURE_VOICE_VOLUME[voice] ?? null,
      suggestedVolume: suggestSsmlVolume(
        averageLufs,
        Math.max(...rows.map((row) => row.truePeakDbtp)),
        targetLufs,
      ),
    };
  });
}

export function buildNativeEnglishListeningPairs(
  measurements: readonly VoiceMeasurement[],
  nativeVoiceId: string,
  englishVoiceId = "jenny-en-gentle",
): ListeningPair[] {
  const byVoiceAndSeed = new Map<string, VoiceMeasurement>();
  for (const measurement of measurements) {
    const key = `${measurement.voiceId}\0${measurement.seedId}`;
    if (byVoiceAndSeed.has(key)) {
      throw new Error(
        `Duplicate measurement for ${measurement.voiceId}/${measurement.seedId}`,
      );
    }
    byVoiceAndSeed.set(key, measurement);
  }
  return measurements.filter((row) => row.voiceId === nativeVoiceId).map(
    (native) => {
      const english = byVoiceAndSeed.get(`${englishVoiceId}\0${native.seedId}`);
      if (!english) {
        throw new Error(
          `Missing ${englishVoiceId} measurement for ${native.seedId}`,
        );
      }
      return {
        seedId: native.seedId,
        nativePath: native.path,
        englishPath: english.path,
      };
    },
  );
}

function readAzureCredentials(): { key: string; region: string } {
  const envKey = Deno.env.get("AZURE_SPEECH_KEY") ?? "";
  const envRegion = Deno.env.get("AZURE_SPEECH_REGION") ?? "";
  const values: Record<string, string> = {};
  if (!envKey || !envRegion) {
    let localEnv = "";
    try {
      localEnv = Deno.readTextFileSync(".env");
    } catch {
      localEnv = "";
    }
    for (const line of localEnv.split(/\r?\n/)) {
      const match = line.match(
        /^\s*(AZURE_SPEECH_KEY|AZURE_SPEECH_REGION)\s*=\s*(.*?)\s*$/,
      );
      if (match) values[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
    }
  }
  const key = envKey || values.AZURE_SPEECH_KEY || "";
  const region = envRegion || values.AZURE_SPEECH_REGION || "";
  if (!key || !/^[a-z0-9-]+$/i.test(region)) {
    throw new Error("AZURE_SPEECH_KEY and AZURE_SPEECH_REGION are required");
  }
  return { key, region };
}

function parseLoudnorm(stderr: Uint8Array): { lufs: number; truePeak: number } {
  const text = new TextDecoder().decode(stderr);
  const objects = [...text.matchAll(/\{[^{}]*\}/gs)].reverse();
  for (const match of objects) {
    try {
      const value = JSON.parse(match[0]) as Record<string, unknown>;
      const lufs = Number(value.input_i);
      const truePeak = Number(value.input_tp);
      if (Number.isFinite(lufs) && Number.isFinite(truePeak)) {
        return { lufs, truePeak };
      }
    } catch {
      // Continue to the next FFmpeg JSON object.
    }
  }
  throw new Error("FFmpeg did not return valid loudness measurements");
}

async function measureMp3(
  path: string,
): Promise<{ lufs: number; truePeak: number }> {
  const result = await new Deno.Command("ffmpeg", {
    args: [
      "-hide_banner",
      "-nostats",
      "-i",
      path,
      "-map",
      "0:a:0",
      "-af",
      `loudnorm=I=${TARGET_LUFS}:TP=-1.5:LRA=11:print_format=json`,
      "-f",
      "null",
      "-",
    ],
    stdout: "null",
    stderr: "piped",
  }).output();
  if (result.code !== 0) throw new Error(`FFmpeg failed for ${path}`);
  return parseLoudnorm(result.stderr);
}

async function writeListeningPlaylist(
  path: string,
  pairs: readonly ListeningPair[],
): Promise<void> {
  if (pairs.length === 0) {
    throw new Error("Listening playlist requires at least one pair");
  }
  const args = ["-hide_banner", "-loglevel", "error", "-y"];
  for (const pair of pairs) {
    args.push("-i", pair.nativePath, "-i", pair.englishPath);
  }
  const inputStreams = Array.from(
    { length: pairs.length * 2 },
    (_, index) => `[${index}:a]`,
  ).join("");
  args.push(
    "-filter_complex",
    `${inputStreams}concat=n=${pairs.length * 2}:v=0:a=1[out]`,
    "-map",
    "[out]",
    "-ar",
    "24000",
    "-ac",
    "1",
    "-c:a",
    "libmp3lame",
    "-b:a",
    "160k",
    path,
  );
  const result = await new Deno.Command("ffmpeg", {
    args,
    stdout: "null",
    stderr: "piped",
  }).output();
  if (result.code !== 0) {
    const error = new TextDecoder().decode(result.stderr).trim();
    throw new Error(`FFmpeg failed to create ${path}: ${error}`);
  }
}

function parseArgs(args: readonly string[]) {
  return {
    execute: args.includes("--execute"),
    costApproved: args.includes("--cost-approved"),
    raw: args.includes("--raw"),
  };
}

async function run(): Promise<void> {
  const options = parseArgs(Deno.args);
  const seedPath = new URL(
    "../../SeedContent/seed-sentences.json",
    import.meta.url,
  );
  const seedContent = JSON.parse(await Deno.readTextFile(seedPath)) as {
    sentences: SeedSentence[];
  };
  const items = buildLoudnessCheckWorkItems(seedContent.sentences);
  const billableCharacters = estimateBillableCharacters(items, !options.raw);
  console.log(
    `Azure voice check: ${items.length} requests, ${billableCharacters} billable characters; cap ${BILLABLE_CHARACTER_CAP}.`,
  );
  console.log(
    `SSML mode: ${
      options.raw
        ? "raw without voice volume"
        : `calibrated ${AUDIO_LEVEL_REVISION}`
    }.`,
  );
  if (!options.execute) {
    console.log("DRY RUN: no Azure credentials or network services were read.");
    for (const item of items) {
      console.log(
        `${item.seedId} | ${item.voiceId} | ${item.route.providerVoice}`,
      );
    }
    return;
  }
  if (!options.costApproved) {
    throw new Error(
      "Paid synthesis requires both --execute and --cost-approved",
    );
  }
  assertBillableCharacterCap(billableCharacters);
  const { key, region } = readAzureCredentials();
  const outputRoot = `output/azure-voice-loudness-${
    new Date().toISOString().replace(/[:.]/g, "-")
  }`;
  const audioRoot = `${outputRoot}/audio`;
  await Deno.mkdir(audioRoot, { recursive: true });
  const measurements: VoiceMeasurement[] = [];

  for (const item of items) {
    const request = buildAzureSpeechRequest(
      item.text,
      item.route,
      key,
      region,
      { applyVolume: !options.raw },
    );
    const response = await fetch(request.url, {
      ...request.init,
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) {
      throw new Error(
        `Azure Speech HTTP ${response.status} for ${item.voiceId}/${item.seedId}`,
      );
    }
    const audio = await response.arrayBuffer();
    if (!isLikelyMp3Audio(audio)) {
      throw new Error(
        `Azure returned invalid MP3 for ${item.voiceId}/${item.seedId}`,
      );
    }
    const path = `${audioRoot}/${item.voiceId}__${item.seedId}.mp3`;
    await Deno.writeFile(path, new Uint8Array(audio));
    const measured = await measureMp3(path);
    measurements.push({
      voiceId: item.voiceId,
      seedId: item.seedId,
      providerVoice: item.route.providerVoice,
      voiceProfile: item.voiceProfile,
      billableCharacters: azureBillableCharacterCount(
        item.text,
        item.route,
        { applyVolume: !options.raw },
      ),
      integratedLufs: measured.lufs,
      truePeakDbtp: measured.truePeak,
      sha256: await sha256(audio),
      path,
    });
    console.log(
      `MEASURED ${item.voiceId} ${item.seedId} ${
        measured.lufs.toFixed(2)
      } LUFS ${measured.truePeak.toFixed(2)} dBTP`,
    );
  }

  const summaries = summarizeMeasurements(measurements);
  const acceptance = summaries.map((summary) => ({
    voiceId: summary.voiceId,
    meanWithinTolerance: Math.abs(summary.deviationFromTargetLufs) <= 0.5,
    peakWithinLimit: summary.maxTruePeakDbtp <= -1,
  }));
  const listeningPairRoot = `${outputRoot}/listening-pairs`;
  await Deno.mkdir(listeningPairRoot, { recursive: true });
  const listeningPlaylists = {
    zhEn: {
      path: `${listeningPairRoot}/zh-en-alternating.mp3`,
      pairs: buildNativeEnglishListeningPairs(
        measurements,
        "hsiaochen-zh-gentle",
      ),
    },
    jaEn: {
      path: `${listeningPairRoot}/ja-en-alternating.mp3`,
      pairs: buildNativeEnglishListeningPairs(measurements, "nanami-ja-gentle"),
    },
  };
  await writeListeningPlaylist(
    listeningPlaylists.zhEn.path,
    listeningPlaylists.zhEn.pairs,
  );
  await writeListeningPlaylist(
    listeningPlaylists.jaEn.path,
    listeningPlaylists.jaEn.pairs,
  );
  const report = {
    generatedAt: new Date().toISOString(),
    levelRevision: options.raw ? null : AUDIO_LEVEL_REVISION,
    raw: options.raw,
    targetLufs: TARGET_LUFS,
    billableCharacters,
    measurements,
    summaries,
    acceptance,
    listeningPlaylists,
  };
  await Deno.writeTextFile(
    `${outputRoot}/measurements.json`,
    JSON.stringify(report, null, 2),
  );
  console.log(JSON.stringify({ outputRoot, summaries }, null, 2));
  if (
    acceptance.some((result) =>
      !result.meanWithinTolerance || !result.peakWithinLimit
    )
  ) {
    throw new Error(
      "Azure voice loudness acceptance failed; see measurements.json",
    );
  }
}

if (import.meta.main) {
  await run();
}
