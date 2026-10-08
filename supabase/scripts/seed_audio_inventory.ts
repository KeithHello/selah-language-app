#!/usr/bin/env -S deno run --allow-net --allow-env --allow-read
/**
 * Read-only inventory for the required 30 seed sentences x 4 voice profiles.
 * It never calls OpenAI, Storage upload, or a database mutation.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const env = Deno.env.toObject();
const supabaseUrl = env.SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
}

const voices = [
  "gentle-natural",
  "clear-slow",
  "daily-bright",
  "elegant-british",
] as const;
const expectedVoices = {
  "gentle-natural": { model: "azure-speech/en-US-JennyNeural", speed: 1 },
  "clear-slow": { model: "azure-speech/en-US-JennyNeural", speed: 0.9 },
  "daily-bright": { model: "azure-speech/en-US-GuyNeural", speed: 1.05 },
  "elegant-british": { model: "azure-speech/en-GB-SoniaNeural", speed: 1 },
} as const;
const seedPath = new URL(
  "../../SeedContent/seed-sentences.json",
  import.meta.url,
);
const seedContent = JSON.parse(await Deno.readTextFile(seedPath)) as {
  sentences: Array<{ id: string }>;
};
const seeds = seedContent.sentences.map((sentence) => sentence.id);

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});
const { data, error } = await supabase
  .from("audio_manifests")
  .select(
    "seed_sentence_id,voice_profile,generation_status,storage_path,content_hash,sha256,byte_size,tts_model,speed,audio_format",
  )
  .not("seed_sentence_id", "is", null);

if (error) throw error;

const rows = data ?? [];
const ready = rows.filter((row) => row.generation_status === "ready");
const readyByKey = new Map(
  ready.map((row) => [`${row.seed_sentence_id}:${row.voice_profile}`, row]),
);
const missing: string[] = [];
const malformed: string[] = [];

for (const seed of seeds) {
  for (const voice of voices) {
    const key = `${seed}:${voice}`;
    const row = readyByKey.get(key);
    if (!row) {
      missing.push(key);
      continue;
    }
    if (
      row.tts_model !== expectedVoices[voice].model ||
      Number(row.speed) !== expectedVoices[voice].speed ||
      typeof row.content_hash !== "string" ||
      !row.content_hash.includes(":lufs-v1:") ||
      row.audio_format !== "mp3" ||
      typeof row.byte_size !== "number" ||
      row.byte_size <= 0 ||
      !/^[a-f0-9]{64}$/.test(String(row.sha256 ?? ""))
    ) {
      malformed.push(key);
    }
  }
}

const byVoice = Object.fromEntries(
  voices.map((voice) => [
    voice,
    ready.filter((row) => row.voice_profile === voice).length,
  ]),
);

console.log(JSON.stringify(
  {
    rows: rows.length,
    ready: ready.length,
    expected: seeds.length * voices.length,
    present: seeds.length * voices.length - missing.length,
    missing: missing.length,
    malformed: malformed.length,
    missingList: missing,
    malformedList: malformed,
    byVoice,
  },
  null,
  2,
));
