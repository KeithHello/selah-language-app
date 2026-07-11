#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env
/**
 * Selah M2 seed audio prebuild tool.
 *
 * Default is dry-run and makes zero OpenAI or Storage calls.
 * Pass --execute only after explicit cost approval: 30 sentences x 4 voices = 120 requests.
 *
 * Required for --execute:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   OPENAI_API_KEY
 *
 * Usage:
 *   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_audio_prebuild.ts
 *   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_audio_prebuild.ts --execute
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  contentHash,
  estimatedDurationMs,
  seedScope,
  seedStoragePath,
  sha256,
  TTS_MODEL,
  TTS_SPEED,
  VOICE_MAP,
} from "../functions/_shared/audio.ts";

const execute = Deno.args.includes("--execute");
const seedPath = new URL("../../SeedContent/seed-sentences.json", import.meta.url);
const seed = JSON.parse(await Deno.readTextFile(seedPath));
const voices = Object.keys(VOICE_MAP);
const workItems = seed.sentences.flatMap((sentence: { id: string; en_translation: string }) =>
  voices.map((voiceProfile) => ({
    seedSentenceId: sentence.id,
    targetText: sentence.en_translation,
    voiceProfile,
  }))
);

console.log(`Seed audio plan: ${seed.sentences.length} sentences x ${voices.length} voices = ${workItems.length} MP3 files.`);
console.log(`Model: ${TTS_MODEL}, speed: ${TTS_SPEED}, format: ${AUDIO_FORMAT}.`);

if (!execute) {
  console.log("DRY RUN ONLY: no OpenAI or Supabase requests will be made.");
  for (const item of workItems) {
    const hash = await contentHash(item.targetText, item.voiceProfile);
    console.log(`${item.seedSentenceId} | ${item.voiceProfile} | ${seedStoragePath(item.seedSentenceId, item.voiceProfile, hash)}`);
  }
  Deno.exit(0);
}

const supabaseURL = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const openAIKey = Deno.env.get("OPENAI_API_KEY");
if (!supabaseURL || !serviceRoleKey || !openAIKey) {
  console.error("ERROR: --execute requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and OPENAI_API_KEY.");
  Deno.exit(1);
}

const supabase = createClient(supabaseURL, serviceRoleKey);
let generated = 0;
let skipped = 0;
let failed = 0;

for (const item of workItems) {
  const hash = await contentHash(item.targetText, item.voiceProfile);
  const scopeKey = seedScope(item.seedSentenceId);
  const path = seedStoragePath(item.seedSentenceId, item.voiceProfile, hash);

  const { data: existing } = await supabase
    .from("audio_manifests")
    .select("id, generation_status")
    .eq("scope_key", scopeKey)
    .eq("content_hash", hash)
    .maybeSingle();

  if (existing?.generation_status === "ready") {
    skipped++;
    continue;
  }

  const voice = VOICE_MAP[item.voiceProfile];
  try {
    const response = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${openAIKey}` },
      body: JSON.stringify({
        model: TTS_MODEL,
        input: item.targetText,
        voice,
        response_format: AUDIO_FORMAT,
        speed: TTS_SPEED,
      }),
    });
    if (!response.ok) throw new Error(`OpenAI HTTP ${response.status}`);

    const buffer = await response.arrayBuffer();
    const checksum = await sha256(buffer);
    const { error: uploadError } = await supabase.storage.from(AUDIO_BUCKET).upload(path, new Uint8Array(buffer), {
      contentType: "audio/mpeg",
      upsert: true,
    });
    if (uploadError) throw uploadError;

    const { error: manifestError } = await supabase.from("audio_manifests").upsert({
      owner_user_id: null,
      sentence_id: null,
      seed_sentence_id: item.seedSentenceId,
      scope_key: scopeKey,
      voice_profile: item.voiceProfile,
      content_hash: hash,
      storage_path: path,
      tts_model: TTS_MODEL,
      speed: TTS_SPEED,
      audio_format: AUDIO_FORMAT,
      byte_size: buffer.byteLength,
      duration_ms: estimatedDurationMs(item.targetText),
      sha256: checksum,
      generation_status: "ready",
      error_code: null,
    }, { onConflict: "scope_key,content_hash" });
    if (manifestError) throw manifestError;

    generated++;
    console.log(`READY ${item.seedSentenceId} / ${item.voiceProfile}`);
  } catch (error) {
    failed++;
    console.error(`FAILED ${item.seedSentenceId} / ${item.voiceProfile}: ${error}`);
  }
}

console.log(JSON.stringify({ generated, skipped, failed, total: workItems.length }));
if (failed > 0) Deno.exit(1);
