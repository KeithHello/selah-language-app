// Shared contract for billable provider usage.  The existing
// generation_requests/usage_records tables remain responsible for rate limits;
// this module records one row per actual external provider attempt.

export const PRICE_VERSION = "openai-standard-2026-09-07";

const TEXT_INPUT_USD_PER_TOKEN = 0.15 / 1_000_000;
const TEXT_OUTPUT_USD_PER_TOKEN = 0.60 / 1_000_000;
const TTS_USD_PER_CHARACTER = 15 / 1_000_000;
const TRANSCRIPTION_USD_PER_MINUTE = 0.003;

export type GenerationFeature =
  | "transcription"
  | "sentence"
  | "preparation"
  | "batch"
  | "tts";

export type ProviderStatus = "started" | "succeeded" | "failed" | "unknown";
export type DeliveryStatus = "pending" | "succeeded" | "failed";
export type UsageSource = "provider" | "request_estimate" | "unknown";
export type CostBasis =
  | "text_tokens"
  | "tts_characters"
  | "transcription_duration"
  | "unknown";

export interface GenerationUsageInput {
  userId: string;
  clientRequestId: string;
  feature: GenerationFeature;
  model: string;
  itemCount?: number;
  inputTokens?: bigint;
  cachedInputTokens?: bigint;
  outputTokens?: bigint;
  audioInputTokens?: bigint;
  textInputTokens?: bigint;
  inputCharacters?: number;
  durationMs?: number;
  usageSource?: UsageSource;
}

export interface ProviderUsage {
  inputTokens?: bigint;
  cachedInputTokens?: bigint;
  outputTokens?: bigint;
  audioInputTokens?: bigint;
  textInputTokens?: bigint;
  inputCharacters?: number;
  durationMs?: number;
  usageSource?: UsageSource;
}

export interface AttemptCompletion {
  deliveryStatus: DeliveryStatus;
  httpStatus?: number;
  errorCode?: string;
  providerRequestId?: string | null;
  usage?: ProviderUsage;
}

export interface GenerationUsageTable {
  insert(values: Record<string, unknown>): Promise<{
    data: { id: string } | null;
    error: unknown;
  }>;
  update(
    id: string,
    values: Record<string, unknown>,
  ): Promise<{ error: unknown }>;
}

export type GenerationUsageRow = Record<string, unknown>;

export interface SupabaseLikeClient {
  from(table: string): {
    insert(values: GenerationUsageRow): {
      select(columns?: string): {
        single(): PromiseLike<{
          data: { id: string } | null;
          error: unknown;
        }>;
      };
    };
    update(values: GenerationUsageRow): {
      eq(column: string, value: string): PromiseLike<{ error: unknown }>;
    };
  };
}

export interface GenerationUsageRecorder {
  readonly id: string;
  succeed(completion: AttemptCompletion): Promise<void>;
  fail(completion: AttemptCompletion): Promise<void>;
  unknown(completion?: AttemptCompletion): Promise<void>;
}

export interface CostEstimate {
  basis: CostBasis;
  usageSource: UsageSource;
  priceVersion: string | null;
  estimatedCostUsd: string | null;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const FEATURES = new Set<GenerationFeature>([
  "transcription",
  "sentence",
  "preparation",
  "batch",
  "tts",
]);

function positiveInteger(
  value: number | undefined,
  name: string,
): number | undefined {
  if (value === undefined) return undefined;
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${name} must be a non-negative safe integer`);
  }
  return value;
}

function nonNegativeBigInt(
  value: bigint | undefined,
  name: string,
): bigint | undefined {
  if (value === undefined) return undefined;
  if (value < 0n) throw new Error(`${name} must be non-negative`);
  return value;
}

export function estimateGenerationCost(input: {
  feature: GenerationFeature;
  usageSource?: UsageSource;
  inputTokens?: bigint;
  cachedInputTokens?: bigint;
  outputTokens?: bigint;
  audioInputTokens?: bigint;
  textInputTokens?: bigint;
  inputCharacters?: number;
  durationMs?: number;
}): CostEstimate {
  const usageSource = input.usageSource ?? "unknown";
  const base = {
    usageSource,
    priceVersion: null as string | null,
    estimatedCostUsd: null as string | null,
  };

  if (usageSource === "unknown") {
    return { ...base, basis: "unknown" };
  }

  if (
    input.feature === "sentence" || input.feature === "preparation" ||
    input.feature === "batch"
  ) {
    const prompt = nonNegativeBigInt(input.inputTokens, "inputTokens");
    const cached =
      nonNegativeBigInt(input.cachedInputTokens, "cachedInputTokens") ?? 0n;
    const completion = nonNegativeBigInt(input.outputTokens, "outputTokens") ??
      0n;
    if (prompt === undefined || (cached > prompt && prompt !== 0n)) {
      return { ...base, basis: "unknown" };
    }
    // The current price snapshot has no confirmed cached-token discount for
    // these Chat Completions requests. Cached tokens remain stored separately
    // for reconciliation but are not silently priced at an assumed rate.
    const value = Number(prompt) * TEXT_INPUT_USD_PER_TOKEN +
      Number(completion) * TEXT_OUTPUT_USD_PER_TOKEN;
    return {
      basis: "text_tokens",
      usageSource,
      priceVersion: PRICE_VERSION,
      estimatedCostUsd: value.toFixed(10),
    };
  }

  if (input.feature === "tts") {
    const characters = positiveInteger(
      input.inputCharacters,
      "inputCharacters",
    );
    if (characters === undefined) return { ...base, basis: "unknown" };
    return {
      basis: "tts_characters",
      usageSource: "request_estimate",
      priceVersion: PRICE_VERSION,
      estimatedCostUsd: (characters * TTS_USD_PER_CHARACTER).toFixed(10),
    };
  }

  const durationMs = positiveInteger(input.durationMs, "durationMs");
  if (durationMs === undefined || durationMs === 0) {
    return { ...base, basis: "unknown" };
  }
  return {
    basis: "transcription_duration",
    usageSource: "request_estimate",
    priceVersion: PRICE_VERSION,
    estimatedCostUsd: (durationMs / 60_000 * TRANSCRIPTION_USD_PER_MINUTE)
      .toFixed(10),
  };
}

export function extractChatUsage(data: unknown): ProviderUsage {
  if (!data || typeof data !== "object") return { usageSource: "unknown" };
  const root = data as Record<string, unknown>;
  const usage = root.usage;
  if (!usage || typeof usage !== "object") return { usageSource: "unknown" };
  const record = usage as Record<string, unknown>;
  const details = record.prompt_tokens_details;
  const cached = details && typeof details === "object"
    ? BigInt((details as Record<string, unknown>).cached_tokens as number ?? 0)
    : 0n;
  return {
    usageSource: "provider",
    inputTokens: typeof record.prompt_tokens === "number"
      ? BigInt(record.prompt_tokens)
      : undefined,
    cachedInputTokens: cached,
    outputTokens: typeof record.completion_tokens === "number"
      ? BigInt(record.completion_tokens)
      : undefined,
  };
}

function validateStart(input: GenerationUsageInput): Record<string, unknown> {
  if (!UUID_PATTERN.test(input.userId)) throw new Error("invalid userId");
  if (!UUID_PATTERN.test(input.clientRequestId)) {
    throw new Error("invalid clientRequestId");
  }
  if (!FEATURES.has(input.feature)) throw new Error("invalid feature");
  if (!input.model || input.model.length > 200) {
    throw new Error("invalid model");
  }
  const itemCount = positiveInteger(input.itemCount, "itemCount");
  if (itemCount !== undefined && (itemCount < 1 || itemCount > 20)) {
    throw new Error("itemCount must be between 1 and 20");
  }
  const durationMs = positiveInteger(input.durationMs, "durationMs");
  const inputCharacters = positiveInteger(
    input.inputCharacters,
    "inputCharacters",
  );
  const initialEstimate = estimateGenerationCost({
    feature: input.feature,
    usageSource: input.usageSource ??
      (input.feature === "tts" || input.feature === "transcription"
        ? "request_estimate"
        : "unknown"),
    inputTokens: input.inputTokens,
    cachedInputTokens: input.cachedInputTokens,
    outputTokens: input.outputTokens,
    audioInputTokens: input.audioInputTokens,
    textInputTokens: input.textInputTokens,
    inputCharacters,
    durationMs,
  });
  return {
    user_id: input.userId,
    client_request_id: input.clientRequestId,
    feature: input.feature,
    model: input.model,
    started_at: new Date().toISOString(),
    provider_status: "started",
    delivery_status: "pending",
    item_count: itemCount ?? 1,
    input_tokens: input.inputTokens?.toString(),
    cached_input_tokens: input.cachedInputTokens?.toString(),
    output_tokens: input.outputTokens?.toString(),
    audio_input_tokens: input.audioInputTokens?.toString(),
    text_input_tokens: input.textInputTokens?.toString(),
    input_characters: inputCharacters,
    duration_ms: durationMs,
    usage_source: initialEstimate.usageSource,
    estimate_basis: initialEstimate.basis,
    price_version: initialEstimate.priceVersion,
    estimated_cost_usd: initialEstimate.estimatedCostUsd,
  };
}

export async function recordGenerationAttempt(
  table: GenerationUsageTable,
  input: GenerationUsageInput,
): Promise<GenerationUsageRecorder> {
  const values = validateStart(input);
  const result = await table.insert(values);
  if (result.error || !result.data?.id) {
    throw new Error("generation_usage_insert_failed");
  }
  const id = result.data.id;

  async function complete(
    providerStatus: ProviderStatus,
    completion: Partial<AttemptCompletion> = {},
  ): Promise<void> {
    const usageInput = {
      feature: input.feature,
      usageSource: completion.usage?.usageSource ??
        (providerStatus === "succeeded"
          ? (input.feature === "tts" || input.feature === "transcription"
            ? "request_estimate"
            : "provider")
          : "unknown"),
      inputTokens: completion.usage?.inputTokens ?? input.inputTokens,
      cachedInputTokens: completion.usage?.cachedInputTokens ??
        input.cachedInputTokens,
      outputTokens: completion.usage?.outputTokens ?? input.outputTokens,
      audioInputTokens: completion.usage?.audioInputTokens ??
        input.audioInputTokens,
      textInputTokens: completion.usage?.textInputTokens ??
        input.textInputTokens,
      inputCharacters: completion.usage?.inputCharacters ??
        input.inputCharacters,
      durationMs: completion.usage?.durationMs ?? input.durationMs,
    };
    const estimate = estimateGenerationCost(usageInput);
    const update = await table.update(id, {
      finished_at: new Date().toISOString(),
      provider_status: providerStatus,
      delivery_status: completion.deliveryStatus ??
        (providerStatus === "succeeded" ? "succeeded" : "failed"),
      http_status: completion.httpStatus,
      error_code: completion.errorCode?.slice(0, 100) ?? null,
      provider_request_id: completion.providerRequestId?.slice(0, 200) ?? null,
      input_tokens: usageInput.inputTokens?.toString() ?? null,
      cached_input_tokens: usageInput.cachedInputTokens?.toString() ?? null,
      output_tokens: usageInput.outputTokens?.toString() ?? null,
      audio_input_tokens: usageInput.audioInputTokens?.toString() ?? null,
      text_input_tokens: usageInput.textInputTokens?.toString() ?? null,
      input_characters: usageInput.inputCharacters ?? null,
      duration_ms: usageInput.durationMs ?? null,
      usage_source: estimate.usageSource,
      estimate_basis: estimate.basis,
      price_version: estimate.priceVersion,
      estimated_cost_usd: estimate.estimatedCostUsd,
    });
    if (update.error) throw new Error("generation_usage_update_failed");
  }

  return {
    id,
    succeed: (completion) => complete("succeeded", completion),
    fail: (completion) => complete("failed", completion),
    unknown: (completion) => complete("unknown", completion),
  };
}

export function createGenerationUsageTable(
  supabase: SupabaseLikeClient,
): GenerationUsageTable {
  return {
    insert(values: GenerationUsageRow) {
      return Promise.resolve(
        supabase
          .from("generation_usage_attempts")
          .insert(values)
          .select("id")
          .single(),
      );
    },
    update(id: string, values: GenerationUsageRow) {
      return Promise.resolve(
        supabase
          .from("generation_usage_attempts")
          .update(values)
          .eq("id", id),
      );
    },
  };
}

interface BusinessEventClient {
  from(table: "generation_business_events"): {
    insert(values: GenerationUsageRow): PromiseLike<{ error: unknown }>;
  };
}

export async function recordBusinessEvent(
  client: BusinessEventClient,
  values: {
    userId: string;
    feature: "transcription" | "sentence" | "preparation" | "batch" | "tts";
    clientRequestId: string;
    outcome: "completed" | "reused" | "in_progress" | "rate_limited" | "failed";
    itemCount?: number;
  },
): Promise<void> {
  try {
    await Promise.resolve(
      client.from("generation_business_events").insert({
        user_id: values.userId,
        feature: values.feature,
        client_request_id: values.clientRequestId,
        outcome: values.outcome,
        item_count: values.itemCount ?? 1,
      }),
    );
  } catch (error) {
    console.error("Generation business event insert failed", error);
  }
}
