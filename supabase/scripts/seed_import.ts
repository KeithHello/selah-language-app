#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env
// Seed Data Import Script for Selah
// Reads seed-sentences.json and imports into Supabase seed_sentences table.
//
// Usage:
//   SUPABASE_URL=https://ijonabyyppmgvoufgamt.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxx \
//   deno run --allow-net --allow-read --allow-env supabase/scripts/seed_import.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.");
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Read seed data
const seedPath = new URL("../../SeedContent/seed-sentences.json", import.meta.url).pathname;
const seedRaw = await Deno.readTextFile(seedPath);
const seedData = JSON.parse(seedRaw);

console.log(`Found ${seedData.sentences.length} seed sentences.`);
console.log(`Version: ${seedData.version}, Language: ${seedData.language}`);

let inserted = 0;
let failed = 0;

for (const s of seedData.sentences) {
  const record = {
    id: s.id,
    zh_text: s.zh_text,
    en_translation: s.en_translation,
    category: s.category,
    difficulty: s.difficulty,
    deconstruction: JSON.stringify(s.deconstruction),
    vocab_candidates: JSON.stringify(s.vocab_candidates),
    seed_tags: [s.category, s.difficulty],
  };

  // Upsert: insert or update if already exists
  const { error } = await supabase
    .from("seed_sentences")
    .upsert(record, { onConflict: "id" });

  if (error) {
    console.error(`  FAILED: ${s.id} - ${error.message}`);
    failed++;
  } else {
    inserted++;
  }
}

console.log(`\n=== Import Complete ===`);
console.log(`  Inserted/Updated: ${inserted}`);
console.log(`  Failed: ${failed}`);

// Verify
const { count, error: countError } = await supabase
  .from("seed_sentences")
  .select("*", { count: "exact", head: true });

if (!countError) {
  console.log(`  Total seed sentences in DB: ${count}`);
}
