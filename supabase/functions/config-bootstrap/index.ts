// Edge Function: /v1/config/bootstrap
// Returns voice profiles, seed sentence packs, prompt/config versions,
// and feature flags. Called by the iOS app on first launch.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { json, errorResponse, handleOptions, requireAuth } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();

  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;

  if (req.method !== "GET") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  let seedSentences: unknown[] = [];

  if (supabaseUrl && supabaseKey) {
    try {
      const supabase = createClient(supabaseUrl, supabaseKey);
      const { data, error } = await supabase
        .from("seed_sentences")
        .select("id, zh_text, en_translation, category, difficulty, deconstruction, vocab_candidates, seed_tags")
        .order("category", { ascending: true });

      if (!error && data) {
        seedSentences = data;
      }
    } catch (err) {
      console.error("Failed to fetch seed sentences:", err);
    }
  }

  return json({
    sourceLanguages: ["zh-Hant"],
    targetLanguages: ["en"],
    defaultVoiceProfile: "gentle-natural",
    voiceProfiles: [
      {
        id: "gentle-natural",
        label: "溫柔自然",
        description: "速度適中，適合每天跟讀",
        openaiVoice: "nova",
      },
      {
        id: "clear-slow",
        label: "清晰慢速",
        description: "更慢一點，適合剛開始聽",
        openaiVoice: "sage",
      },
      {
        id: "daily-bright",
        label: "日常輕快",
        description: "比較像朋友說話的速度",
        openaiVoice: "ash",
      },
    ],
    seedSentences,
    seedSentencePackVersion: "v1.0",
    promptVersion: "v8.0",
    featureFlags: {
      enable_japanese: false,
      enable_sync: false,
      enable_credits: false,
      enable_analytics: true,
    },
  });
});
