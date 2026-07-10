// Edge Function: /v1/sentences/generate
// Generates English learning material from a Chinese sentence.
// Calls GPT-4o-mini with the v8 translation system prompt.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { CORS_HEADERS, json, errorResponse, handleOptions, requireAuth } from "../_shared/cors.ts";

const SYSTEM_PROMPT = `You are a teaching-oriented translation engine for the language learning app "Selah."

## Your Role
Your job is to help a Traditional Chinese speaker learn natural spoken English. You receive a Chinese sentence that the user actually said or typed in their real life, and you generate an English version they can understand, hear, practice, and eventually use in real conversations.

## Core Translation Rules

1. **Natural spoken English first.** The output must sound like something a real person would say out loud. Avoid textbook English, stiff grammar, or overly formal phrasing.

2. **Preserve intent and tone.** The user chose to say this sentence. The English must feel like "my sentence" - same meaning, same emotional tone, same level of casualness or seriousness.

3. **Slightly above current level, but usable.** Use vocabulary and phrasing that is reachable.

4. **Consistent phrasing.** If the user says a similar sentence tomorrow, translate it consistently.

## Vocabulary Candidates: Selection Rules

After translating, suggest 2-4 words or phrases that are worth the user's attention:
- **Scene-relevant only.** Suggest expressions useful for saying similar things.
- **Skip basic function words.** Do NOT suggest: I, you, the, a, is, am, are, it, this, that, and, or, but, in, on, at, to, for, of, with.
- **Prefer phrases over single words.** "get off on time" is better than "time" alone.
- **Max 3 candidates per sentence.**

## Category Classification

Classify into one of: work, friends, vent, heartfelt, debate, daily_life

## Output Format

Return ONLY valid JSON with this exact structure:

{
  "targetText": "natural English here",
  "category": "one of the six categories",
  "vocabulary": [
    { "surfaceText": "exact phrase", "meaningInContext": "context-specific Chinese meaning", "suggestedHelpState": "new" }
  ],
  "deconstruction": [
    { "surfaceText": "exact phrase", "meaning": "short Chinese meaning", "type": "phrase" }
  ]
}`;

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

interface RequestBody {
  sourceText: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  categoryHint?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();

  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  const userId = authResult;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  if (!body.sourceText || body.sourceText.trim().length === 0) {
    return errorResponse("sourceText is required", 400, "missing_source_text");
  }

  if (body.sourceText.length > 500) {
    return errorResponse("sourceText too long (max 500 chars)", 400, "text_too_long");
  }

  try {
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: body.sourceText },
        ],
        temperature: 0.7,
        response_format: { type: "json_object" },
      }),
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error("OpenAI API error:", openaiResponse.status, errText);
      return errorResponse("Translation service unavailable", 502, "translation_failed");
    }

    const openaiData = await openaiResponse.json();
    const content = openaiData.choices?.[0]?.message?.content;

    if (!content) {
      return errorResponse("Empty translation response", 502, "translation_empty");
    }

    let parsed: {
      targetText: string;
      category: string;
      vocabulary: Array<{ surfaceText: string; meaningInContext: string; suggestedHelpState: string }>;
      deconstruction: Array<{ surfaceText: string; meaning: string; type: string }>;
    };

    try {
      parsed = JSON.parse(content);
    } catch {
      console.error("Failed to parse LLM output:", content);
      return errorResponse("Invalid translation format", 502, "translation_format_error");
    }

    // Validate required fields
    if (!parsed.targetText || typeof parsed.targetText !== "string") {
      return errorResponse("Missing targetText in translation", 502, "translation_missing_fields");
    }

    // Record usage (dormant in MVP, for future billing)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey);
      await supabase.from("usage_records").insert({
        user_id: userId,
        operation_type: "sentence_generation",
        estimated_units: 1,
        client_request_id: crypto.randomUUID(),
      });
    }

    return json({
      targetText: parsed.targetText,
      category: parsed.category ?? body.categoryHint ?? "daily_life",
      vocabulary: parsed.vocabulary ?? [],
      deconstruction: parsed.deconstruction ?? [],
      promptVersion: "v8.0",
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    return errorResponse("Internal server error", 500, "internal_error");
  }
});
