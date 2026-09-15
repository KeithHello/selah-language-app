export const AUDIENCE_DIMENSIONS = [
  "learningGoal",
  "englishLevel",
  "ageGroup",
  "lifeStage",
  "gender",
] as const;

export type AudienceDimension = (typeof AUDIENCE_DIMENSIONS)[number];

export type AudienceQueryResult =
  | {
    ok: true;
    dimension: AudienceDimension;
    start: string;
    end: string;
  }
  | {
    ok: false;
    code: "invalid_dimension" | "invalid_period";
    message: string;
  };

export function normalizeAudienceQuery(input: {
  dimension?: unknown;
  start?: unknown;
  end?: unknown;
}): AudienceQueryResult {
  if (
    typeof input.dimension !== "string" ||
    !(AUDIENCE_DIMENSIONS as readonly string[]).includes(input.dimension)
  ) {
    return {
      ok: false,
      code: "invalid_dimension",
      message: "A single supported audience dimension is required",
    };
  }
  if (typeof input.start !== "string" || typeof input.end !== "string") {
    return {
      ok: false,
      code: "invalid_period",
      message: "A valid UTC period is required",
    };
  }
  const startDate = new Date(input.start);
  const endDate = new Date(input.end);
  const duration = endDate.getTime() - startDate.getTime();
  if (
    !Number.isFinite(startDate.getTime()) ||
    !Number.isFinite(endDate.getTime()) ||
    duration <= 0 ||
    duration > 93 * 86_400_000
  ) {
    return {
      ok: false,
      code: "invalid_period",
      message: "The period is invalid or longer than 93 days",
    };
  }
  return {
    ok: true,
    dimension: input.dimension as AudienceDimension,
    start: startDate.toISOString(),
    end: endDate.toISOString(),
  };
}
