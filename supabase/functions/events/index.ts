// Edge Function: /v1/events
// Privacy-minimal event ingestion for learning analytics.
// Never stores raw sentence text.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  ALLOWED_EVENT_TYPES,
  sanitizeEventMetadata,
} from "../_shared/event_contract.ts";

interface RequestBody {
  eventType: string;
  sentenceId?: string;
  metadata?: Record<string, unknown>;
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

  if (!body.eventType || !ALLOWED_EVENT_TYPES.has(body.eventType)) {
    return errorResponse(
      `Invalid event type. Allowed: ${
        Array.from(ALLOWED_EVENT_TYPES).join(", ")
      }`,
      400,
      "invalid_event_type",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !supabaseKey) {
    return errorResponse("Server not configured", 500, "server_not_configured");
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    const safeMetadata = sanitizeEventMetadata(body.eventType, body.metadata);

    const { error } = await supabase.from("learning_events").insert({
      user_id: userId,
      sentence_id: body.sentenceId ?? null,
      event_type: body.eventType,
      metadata: safeMetadata,
    });

    if (error) {
      console.error("Learning event insert failed");
      return errorResponse("Failed to record event", 500, "db_error");
    }

    return json({ status: "ok" }, 201);
  } catch {
    console.error("Learning events function failed");
    return errorResponse("Internal server error", 500, "internal_error");
  }
});
