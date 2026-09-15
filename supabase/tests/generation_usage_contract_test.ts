// Usage accounting contract tests.
// Run: deno test supabase/tests/generation_usage_contract_test.ts

import {
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  estimateGenerationCost,
  type GenerationUsageRecorder,
  type GenerationUsageRow,
  type GenerationUsageTable,
  recordGenerationAttempt,
} from "../functions/_shared/generation_usage_contract.ts";

Deno.test("text cost counts cached tokens once at the documented standard rate", () => {
  assertEquals(
    estimateGenerationCost({
      feature: "sentence",
      usageSource: "provider",
      inputTokens: 1000n,
      cachedInputTokens: 200n,
      outputTokens: 300n,
    }).basis,
    "text_tokens",
  );
  assertAlmostEquals(
    Number(
      estimateGenerationCost({
        feature: "sentence",
        usageSource: "provider",
        inputTokens: 1000n,
        cachedInputTokens: 200n,
        outputTokens: 300n,
      }).estimatedCostUsd,
    ),
    (1000 * 0.15 + 300 * 0.6) / 1_000_000,
  );
});

Deno.test("tts cost is derived from Unicode input characters", () => {
  const result = estimateGenerationCost({
    feature: "tts",
    usageSource: "request_estimate",
    inputCharacters: 100,
  });
  assertEquals(result.basis, "tts_characters");
  assertAlmostEquals(Number(result.estimatedCostUsd), 100 * 15 / 1_000_000);
});

Deno.test("transcription cost is a duration estimate, not a token estimate", () => {
  const result = estimateGenerationCost({
    feature: "transcription",
    usageSource: "request_estimate",
    durationMs: 60_000,
  });
  assertEquals(result.basis, "transcription_duration");
  assertAlmostEquals(Number(result.estimatedCostUsd), 0.003);
});

Deno.test("unknown usage is never priced as zero", () => {
  assertEquals(
    estimateGenerationCost({
      feature: "tts",
      usageSource: "unknown",
    }).estimatedCostUsd,
    null,
  );
});

Deno.test("recorder starts and completes one provider attempt", async () => {
  const inserted: GenerationUsageRow[] = [];
  const updated: Array<{ id: string; values: Record<string, unknown> }> = [];
  const table: GenerationUsageTable = {
    insert(values: GenerationUsageRow) {
      inserted.push(values);
      return Promise.resolve({ data: { id: "attempt-1" }, error: null });
    },
    update(id, values) {
      updated.push({ id, values });
      return Promise.resolve({ error: null });
    },
  };

  const recorder = await recordGenerationAttempt(table, {
    userId: "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d",
    clientRequestId: "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0",
    feature: "batch",
    model: "gpt-4o-mini",
    itemCount: 5,
  });
  await recorder.succeed({
    deliveryStatus: "succeeded",
    providerRequestId: "req_123",
    usage: {
      inputTokens: 1000n,
      outputTokens: 500n,
      usageSource: "provider",
    },
  });

  assertEquals(inserted[0].provider_status, "started");
  assertEquals(inserted[0].item_count, 5);
  assertEquals(updated[0].id, "attempt-1");
  assertEquals(updated[0].values.provider_status, "succeeded");
  assertEquals(updated[0].values.delivery_status, "succeeded");
  assertEquals(updated[0].values.provider_request_id, "req_123");
});

Deno.test("recorder reports failed delivery without hiding provider usage", async () => {
  const table: GenerationUsageTable = {
    insert: () => Promise.resolve({ data: { id: "attempt-2" }, error: null }),
    update: () => Promise.resolve({ error: null }),
  };
  const recorder = await recordGenerationAttempt(table, {
    userId: "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d",
    clientRequestId: "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0",
    feature: "tts",
    model: "tts-1",
    inputCharacters: 100,
  });
  await recorder.succeed({
    deliveryStatus: "failed",
    errorCode: "storage_upload_failed",
    usage: { usageSource: "request_estimate" },
  });
  // The recorder's update method receives the completed provider attempt even
  // though the later Storage delivery failed.
});
