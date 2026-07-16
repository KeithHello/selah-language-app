import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  BatchTranslationInput,
  buildBatchTranslationRequest,
  validateBatchTranslationInput,
} from "../_shared/capture_contract.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const MINUTE_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_MINUTE_LIMIT") ?? "5", 10) || 5,
);
const DAILY_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_DAILY_LIMIT") ?? "20", 10) || 20,
);

interface Claim {
  decision:
    | "claimed"
    | "replay"
    | "in_progress"
    | "rate_limited"
    | "quota_exceeded";
  responsePayload: Record<string, unknown> | null;
}

interface BatchItem {
  segmentId: string;
  targetText: string;
  category: string;
  vocabulary: unknown[];
  deconstruction: unknown[];
}

interface RPCClient {
  rpc(name: string, args: Record<string, string>): Promise<unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }
  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Batch generation is not configured",
      503,
      "generation_service_unavailable",
    );
  }

  let body: BatchTranslationInput;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }
  const validation = validateBatchTranslationInput(body);
  if (!validation.ok) {
    return errorResponse(
      validation.message,
      validation.status,
      validation.code,
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const replayed: BatchItem[] = [];
  const claimedIDs: string[] = [];
  for (const segment of validation.segments) {
    const { data: raw, error } = await supabase.rpc(
      "claim_generation_request",
      {
        p_user_id: authResult,
        p_operation_type: "sentence_generation",
        p_client_request_id: segment.segmentId,
        p_minute_limit: MINUTE_LIMIT,
        p_daily_limit: DAILY_LIMIT,
      },
    );
    if (error || !raw) {
      await failClaims(
        supabase as unknown as RPCClient,
        authResult,
        claimedIDs,
      );
      return errorResponse(
        "Generation capacity unavailable",
        503,
        "generation_capacity_unavailable",
      );
    }
    const claim = raw as Claim;
    if (
      claim.decision === "rate_limited" || claim.decision === "quota_exceeded"
    ) {
      await failClaims(
        supabase as unknown as RPCClient,
        authResult,
        claimedIDs,
      );
      return errorResponse(
        claim.decision === "rate_limited"
          ? "Too many generation requests"
          : "Daily generation quota exceeded",
        429,
        claim.decision,
      );
    }
    if (claim.decision === "in_progress") {
      await failClaims(
        supabase as unknown as RPCClient,
        authResult,
        claimedIDs,
      );
      return errorResponse(
        "Request is still in progress",
        429,
        "request_in_progress",
      );
    }
    if (claim.decision === "replay" && claim.responsePayload) {
      replayed.push(claim.responsePayload as unknown as BatchItem);
    } else if (claim.decision === "claimed") {
      claimedIDs.push(segment.segmentId);
    }
  }

  const pending = validation.segments.filter((segment) =>
    claimedIDs.includes(segment.segmentId)
  );
  if (pending.length === 0) {
    return json({ items: replayed.sort(sortBySegment) });
  }

  try {
    const providerResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify(buildBatchTranslationRequest(
          pending.map(({ segmentId, sourceText }) => ({
            segmentId,
            sourceText,
          })),
          validation.sourceLanguage,
          validation.targetLanguage,
          validation.categoryHint,
        )),
      },
    );
    if (!providerResponse.ok) throw new Error("provider_failed");
    const data = await providerResponse.json();
    const content = data.choices?.[0]?.message?.content;
    const parsed = typeof content === "string"
      ? JSON.parse(content) as { items?: unknown }
      : {};
    const items = normalizeItems(
      parsed.items,
      new Set(pending.map((segment) => segment.segmentId)),
    );
    if (items.length !== pending.length) {
      throw new Error("provider_items_mismatch");
    }

    for (const item of items) {
      const { error } = await supabase.rpc("complete_generation_request", {
        p_user_id: authResult,
        p_operation_type: "sentence_generation",
        p_client_request_id: item.segmentId,
        p_response_payload: item,
      });
      if (error) throw new Error("completion_failed");
    }
    return json({ items: [...replayed, ...items].sort(sortBySegment) });
  } catch {
    await failClaims(supabase as unknown as RPCClient, authResult, claimedIDs);
    console.error("Batch sentence generation failed");
    return errorResponse("Batch generation failed", 502, "generation_failed");
  }
});

function normalizeItems(value: unknown, expectedIDs: Set<string>): BatchItem[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  return value.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const candidate = item as Record<string, unknown>;
    const segmentId = typeof candidate.segmentId === "string"
      ? candidate.segmentId.toLowerCase()
      : "";
    const targetText = typeof candidate.targetText === "string"
      ? candidate.targetText.trim()
      : "";
    if (
      !expectedIDs.has(segmentId) || seen.has(segmentId) || !targetText ||
      targetText.length > 1000
    ) return [];
    seen.add(segmentId);
    return [{
      segmentId,
      targetText,
      category: normalizeCategory(candidate.category),
      vocabulary: Array.isArray(candidate.vocabulary)
        ? candidate.vocabulary
        : [],
      deconstruction: Array.isArray(candidate.deconstruction)
        ? candidate.deconstruction
        : [],
    }];
  });
}

function normalizeCategory(value: unknown): string {
  const categories = new Set([
    "work",
    "friends",
    "vent",
    "heartfelt",
    "debate",
    "daily_life",
  ]);
  return typeof value === "string" && categories.has(value)
    ? value
    : "daily_life";
}

function sortBySegment(a: BatchItem, b: BatchItem): number {
  return a.segmentId.localeCompare(b.segmentId);
}

async function failClaims(
  client: RPCClient,
  userID: string,
  IDs: string[],
) {
  await Promise.all(
    IDs.map((clientRequestId) =>
      client.rpc("fail_generation_request", {
        p_user_id: userID,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      })
    ),
  );
}
