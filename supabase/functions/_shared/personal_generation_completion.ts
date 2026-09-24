export interface PersonalGenerationCompletionItem {
  requestId: string;
  responsePayload: Record<string, unknown>;
}

export interface PersonalGenerationCompletionInput {
  userId: string;
  parentRequestId: string;
  reservationId: string | null;
  items: PersonalGenerationCompletionItem[];
  /**
   * The server-side service-control snapshot. Legacy completion is only
   * allowed when membership enforcement is explicitly disabled and the new
   * atomic RPC is absent. An unknown value never enables the fallback.
   */
  enforcementEnabled?: boolean;
}

export interface PersonalGenerationCompletionResult {
  items: PersonalGenerationCompletionItem[];
  trialState?: string;
  trialStartedAt?: string | null;
  trialExpiresAt?: string | null;
  [key: string]: unknown;
}

export interface PersonalGenerationCompletionClient {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message?: string } | null }>;
}

export class PersonalGenerationCompletionError extends Error {
  readonly code:
    | "invalid_completion_input"
    | "generation_completion_unavailable";

  constructor(
    message: string,
    code:
      | "invalid_completion_input"
      | "generation_completion_unavailable",
  ) {
    super(message);
    this.name = "PersonalGenerationCompletionError";
    this.code = code;
  }
}

function invalid(message: string): never {
  throw new PersonalGenerationCompletionError(
    message,
    "invalid_completion_input",
  );
}

function validateInput(input: PersonalGenerationCompletionInput): void {
  if (!input || typeof input !== "object") {
    invalid("Completion input is required");
  }
  if (!input.userId || typeof input.userId !== "string") {
    invalid("Completion user is required");
  }
  if (!input.parentRequestId || typeof input.parentRequestId !== "string") {
    invalid("Completion parent request is required");
  }
  if (input.reservationId !== null && typeof input.reservationId !== "string") {
    invalid("Completion reservation is invalid");
  }
  if (!Array.isArray(input.items) || input.items.length === 0) {
    invalid("At least one completion item is required");
  }
  const seen = new Set<string>();
  for (const item of input.items) {
    if (
      !item || typeof item.requestId !== "string" || item.requestId.length === 0
    ) {
      invalid("Completion item request is invalid");
    }
    if (seen.has(item.requestId)) {
      invalid("Completion item request is duplicated");
    }
    seen.add(item.requestId);
    if (!item.responsePayload || typeof item.responsePayload !== "object") {
      invalid("Completion item payload is invalid");
    }
  }
}

export async function completePersonalGeneration(
  client: PersonalGenerationCompletionClient,
  input: PersonalGenerationCompletionInput,
): Promise<PersonalGenerationCompletionResult> {
  validateInput(input);
  const { data, error } = await client.rpc("complete_personal_generation", {
    p_user_id: input.userId,
    p_parent_request_id: input.parentRequestId,
    p_reservation_id: input.reservationId,
    p_items: input.items,
  });
  if (!error && data && typeof data === "object") {
    return data as PersonalGenerationCompletionResult;
  }

  if (
    input.enforcementEnabled === false &&
    isMissingPersonalCompletionRpc(error)
  ) {
    return completeLegacyGeneration(client, input);
  }

  if (error || !data || typeof data !== "object") {
    throw new PersonalGenerationCompletionError(
      error?.message ?? "Generation completion unavailable",
      "generation_completion_unavailable",
    );
  }
  return data as PersonalGenerationCompletionResult;
}

function isMissingPersonalCompletionRpc(
  error: { message?: string } | null,
): boolean {
  const message = error?.message?.toLowerCase() ?? "";
  return message.includes("complete_personal_generation") && (
    message.includes("not found") ||
    message.includes("schema cache") ||
    message.includes("does not exist") ||
    message.includes("could not find")
  );
}

async function completeLegacyGeneration(
  client: PersonalGenerationCompletionClient,
  input: PersonalGenerationCompletionInput,
): Promise<PersonalGenerationCompletionResult> {
  const completedItems: PersonalGenerationCompletionItem[] = [];
  for (const item of input.items) {
    const { data, error } = await client.rpc("complete_generation_request", {
      p_user_id: input.userId,
      p_operation_type: "sentence_generation",
      p_client_request_id: item.requestId,
      p_response_payload: item.responsePayload,
    });
    if (error) {
      throw new PersonalGenerationCompletionError(
        error.message ?? "Generation completion unavailable",
        "generation_completion_unavailable",
      );
    }
    // The legacy RPC returns a boolean. A false result means the request was
    // already finalized or never claimed; neither is a successful new save.
    if (data !== true) {
      throw new PersonalGenerationCompletionError(
        "Legacy generation completion was not persisted",
        "generation_completion_unavailable",
      );
    }
    completedItems.push(item);
  }
  return { items: completedItems };
}
