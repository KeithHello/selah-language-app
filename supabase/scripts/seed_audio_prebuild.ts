#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env
/**
 * Selah M2 seed audio prebuild tool.
 *
 * Default is dry-run and makes no network requests or environment reads.
 * Pass both --execute and --cost-approved only after reviewing the printed
 * Azure character and cost estimate. Each sentence gets four English profiles.
 *
 * Required for --execute:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   AZURE_SPEECH_KEY
 *   AZURE_SPEECH_REGION
 *   AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER
 *   AZURE_TTS_PRICE_VERSION
 *
 * Usage:
 *   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_audio_prebuild.ts
 *   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_audio_prebuild.ts --voice gentle-natural
 *   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_audio_prebuild.ts --execute --cost-approved
 */

import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  AUDIO_LEVEL_REVISION,
  mp3DurationMs,
  seedScope,
  seedStoragePath,
  sha256,
  textContentHash,
} from "../functions/_shared/audio.ts";
import {
  audioCacheKey,
  type AudioRoute,
  resolveAudioRoute,
} from "../functions/_shared/audio_routing.ts";
import {
  azureBillableCharacterCount,
  buildAzureSpeechRequest,
} from "../functions/_shared/azure_speech.ts";
import { isLikelyMp3Audio } from "../functions/_shared/audio_generation_policy.ts";

const execute = Deno.args.includes("--execute");
const costApproved = Deno.args.includes("--cost-approved");
const voiceIndex = Deno.args.indexOf("--voice");
const voiceFilter = voiceIndex >= 0 ? Deno.args[voiceIndex + 1] : undefined;
const voices = [
  "gentle-natural",
  "clear-slow",
  "daily-bright",
  "elegant-british",
] as const;
if (voiceFilter && !(voices as readonly string[]).includes(voiceFilter)) {
  console.error(
    `ERROR: unknown voice "${voiceFilter}". Available: ${voices.join(", ")}.`,
  );
  Deno.exit(1);
}
const seedPath = new URL(
  "../../SeedContent/seed-sentences.json",
  import.meta.url,
);
const seed = JSON.parse(await Deno.readTextFile(seedPath));
const selectedVoices = voiceFilter ? [voiceFilter] : [...voices];
const workItems = seed.sentences.flatMap((
  sentence: { id: string; en_translation: string },
) =>
  selectedVoices.map((voiceProfile) => {
    const result = resolveAudioRoute({
      audioRole: "target",
      targetLanguage: "en",
      voiceProfile,
    });
    if (!result.ok) throw new Error(result.message);
    return {
      seedSentenceId: sentence.id,
      targetText: sentence.en_translation,
      voiceProfile,
      route: result.route,
    };
  })
);

console.log(
  `Azure seed plan: ${seed.sentences.length} sentences x ${selectedVoices.length} English voices = ${workItems.length} MP3 files.`,
);
const totalBillableCharacters = workItems.reduce(
  (total: number, item: { targetText: string; route: AudioRoute }) =>
    total + azureBillableCharacterCount(item.targetText, item.route),
  0,
);
console.log(
  `Format: ${AUDIO_FORMAT}; level revision: ${AUDIO_LEVEL_REVISION}.`,
);
console.log(`Estimated Azure billable characters: ${totalBillableCharacters}.`);

async function seedIdentity(item: {
  targetText: string;
  voiceProfile: string;
  route: AudioRoute;
}): Promise<{ textHash: string; contentHash: string }> {
  const textHash = await textContentHash(
    item.targetText,
    item.route.language,
    AUDIO_FORMAT,
    AUDIO_LEVEL_REVISION,
  );
  return {
    textHash,
    contentHash: audioCacheKey({
      provider: item.route.provider,
      providerVoice: item.route.providerVoice,
      speed: item.route.speed,
      textHash,
      levelRevision: AUDIO_LEVEL_REVISION,
    }),
  };
}

if (!execute) {
  console.log(
    "DRY RUN ONLY: no environment variables or network services were read.",
  );
  for (const item of workItems) {
    const identity = await seedIdentity(item);
    console.log(
      `${item.seedSentenceId} | ${item.route.providerModel} | ${item.voiceProfile} | ${
        seedStoragePath(
          item.seedSentenceId,
          item.voiceProfile,
          identity.textHash,
        )
      }`,
    );
  }
  Deno.exit(0);
}

if (!costApproved) {
  console.error(
    "ERROR: --execute also requires --cost-approved after cost review.",
  );
  Deno.exit(1);
}

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const azureKey = Deno.env.get("AZURE_SPEECH_KEY");
const azureRegion = Deno.env.get("AZURE_SPEECH_REGION");
const azureRate = Number(
  Deno.env.get("AZURE_TTS_NANO_USD_PER_BILLABLE_CHARACTER"),
);
const priceVersion = Deno.env.get("AZURE_TTS_PRICE_VERSION") ?? "";
if (
  !supabaseURL || !serviceRoleKey || !azureKey || !azureRegion ||
  !/^\d+$/.test(String(azureRate)) || !Number.isSafeInteger(azureRate) ||
  azureRate < 1 ||
  !/^[a-zA-Z0-9._-]{1,80}$/.test(priceVersion)
) {
  console.error(
    "ERROR: --execute requires valid Azure, Supabase, and versioned price configuration.",
  );
  Deno.exit(1);
}

const estimateNanoUsd = BigInt(totalBillableCharacters) * BigInt(azureRate);
console.log(
  `Configured conservative estimate: ${estimateNanoUsd} nano-USD (${priceVersion}).`,
);
const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
const supabase = createClient(supabaseURL, serviceRoleKey);
let generated = 0;
let skipped = 0;
let failed = 0;

for (const item of workItems) {
  const identity = await seedIdentity(item);
  const scopeKey = seedScope(item.seedSentenceId);
  const path = seedStoragePath(
    item.seedSentenceId,
    item.voiceProfile,
    identity.textHash,
  );

  const { data: existing } = await supabase
    .from("audio_manifests")
    .select("id, generation_status")
    .eq("scope_key", scopeKey)
    .eq("content_hash", identity.contentHash)
    .maybeSingle();

  if (existing?.generation_status === "ready") {
    skipped++;
    continue;
  }

  try {
    const request = buildAzureSpeechRequest(
      item.targetText,
      item.route,
      azureKey,
      azureRegion,
    );
    const response = await fetch(request.url, {
      ...request.init,
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) throw new Error(`Azure Speech HTTP ${response.status}`);

    const sourceAudio = await response.arrayBuffer();
    if (!isLikelyMp3Audio(sourceAudio)) {
      throw new Error("Azure returned invalid MP3");
    }
    const buffer = sourceAudio;
    const checksum = await sha256(buffer);
    const { error: uploadError } = await supabase.storage.from(AUDIO_BUCKET)
      .upload(path, new Uint8Array(buffer), {
        contentType: "audio/mpeg",
        upsert: true,
      });
    if (uploadError) throw uploadError;

    const { error: manifestError } = await supabase.from("audio_manifests")
      .upsert({
        owner_user_id: null,
        sentence_id: null,
        seed_sentence_id: item.seedSentenceId,
        scope_key: scopeKey,
        voice_profile: item.voiceProfile,
        content_hash: identity.contentHash,
        storage_path: path,
        tts_model: item.route.providerModel,
        speed: item.route.speed,
        audio_format: AUDIO_FORMAT,
        byte_size: buffer.byteLength,
        duration_ms: mp3DurationMs(buffer.byteLength),
        sha256: checksum,
        generation_status: "ready",
        error_code: null,
      }, { onConflict: "scope_key,content_hash" });
    if (manifestError) throw manifestError;

    generated++;
    console.log(`READY ${item.seedSentenceId} / ${item.voiceProfile}`);
  } catch (error) {
    failed++;
    console.error(
      `FAILED ${item.seedSentenceId} / ${item.voiceProfile}: ${error}`,
    );
  }
}

console.log(
  JSON.stringify({ generated, skipped, failed, total: workItems.length }),
);
if (failed > 0) Deno.exit(1);
