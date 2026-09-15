// Stable, intentionally small contract for optional user research answers.
// This module is pure so it can be tested without a Supabase or provider client.

export const PROFILE_NOTICE_VERSION = "2026-09-12-v1";
export const PROFILE_OPERATIONS = ["offer", "save", "skip", "withdraw"] as const;
export type ProfileOperation = (typeof PROFILE_OPERATIONS)[number];

export const PROFILE_ENUMS = {
  learningGoal: ["work", "daily", "travel", "exam", "other", "prefer_not_say"],
  englishLevel: ["starter", "reading_stronger", "conversational", "not_sure", "prefer_not_say"],
  ageGroup: ["under_14", "age_14_17", "age_18_24", "age_25_34", "age_35_44", "age_45_plus", "prefer_not_say"],
  lifeStage: ["student", "employee", "self_employed", "other", "prefer_not_say"],
  gender: ["male", "female", "self_described", "prefer_not_say"],
} as const;

type EnumKey = keyof typeof PROFILE_ENUMS;
type OptionalEnum = string | null;

export interface ResearchProfile {
  learningGoal: OptionalEnum;
  englishLevel: OptionalEnum;
  ageGroup: OptionalEnum;
  lifeStage: OptionalEnum;
  gender: OptionalEnum;
  genderDescription: string | null;
}

export interface ProfileValidationError {
  ok: false;
  code: "profile_invalid_input" | "profile_consent_required" | "profile_notice_changed";
  message: string;
  field?: string;
}

export type ProfileValidationResult =
  | { ok: true; value: ResearchProfile }
  | ProfileValidationError;

export type ProfileOperationValidationResult =
  | { ok: true; operation: ProfileOperation; profile: ResearchProfile | null }
  | ProfileValidationError;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeEnum(
  input: Record<string, unknown>,
  key: EnumKey,
): string | null | ProfileValidationError {
  const value = input[key];
  if (value == null || value === "") return null;
  if (typeof value !== "string" || !(PROFILE_ENUMS[key] as readonly string[]).includes(value)) {
    return {
      ok: false,
      code: "profile_invalid_input",
      field: key,
      message: `Invalid value for ${key}`,
    };
  }
  return value;
}

function codePointLength(value: string): number {
  return [...value].length;
}

export function normalizeResearchProfile(input: unknown): ProfileValidationResult {
  if (!isRecord(input)) {
    return { ok: false, code: "profile_invalid_input", message: "Profile must be an object" };
  }
  const allowed = new Set([
    "learningGoal",
    "englishLevel",
    "ageGroup",
    "lifeStage",
    "gender",
    "genderDescription",
  ]);
  for (const key of Object.keys(input)) {
    if (!allowed.has(key)) {
      return { ok: false, code: "profile_invalid_input", field: key, message: `Unknown profile field: ${key}` };
    }
  }

  const values = {} as Record<EnumKey, string | null>;
  for (const key of Object.keys(PROFILE_ENUMS) as EnumKey[]) {
    const result = normalizeEnum(input, key);
    if (result !== null && typeof result === "object") return result;
    values[key] = result;
  }

  const rawDescription = input.genderDescription;
  if (rawDescription != null && typeof rawDescription !== "string") {
    return {
      ok: false,
      code: "profile_invalid_input",
      field: "genderDescription",
      message: "genderDescription must be text",
    };
  }
  const genderDescription = typeof rawDescription === "string"
    ? rawDescription.trim()
    : null;
  if (genderDescription && codePointLength(genderDescription) > 40) {
    return {
      ok: false,
      code: "profile_invalid_input",
      field: "genderDescription",
      message: "genderDescription is too long",
    };
  }
  if (genderDescription && values.gender !== "self_described") {
    return {
      ok: false,
      code: "profile_invalid_input",
      field: "genderDescription",
      message: "genderDescription requires self_described gender",
    };
  }

  return {
    ok: true,
    value: {
      learningGoal: values.learningGoal,
      englishLevel: values.englishLevel,
      ageGroup: values.ageGroup,
      lifeStage: values.lifeStage,
      gender: values.gender,
      genderDescription: genderDescription || null,
    },
  };
}

export function validateProfileOperation(input: {
  operation: unknown;
  profile?: unknown;
  noticeVersion?: unknown;
  researchConsent?: unknown;
}): ProfileOperationValidationResult {
  if (typeof input.operation !== "string" || !(PROFILE_OPERATIONS as readonly string[]).includes(input.operation)) {
    return { ok: false, code: "profile_invalid_input", message: "Unknown profile operation" };
  }
  const operation = input.operation as ProfileOperation;
  if (operation !== "save") return { ok: true, operation, profile: null };
  if (input.noticeVersion !== PROFILE_NOTICE_VERSION) {
    return { ok: false, code: "profile_notice_changed", message: "The privacy notice has changed" };
  }
  if (input.researchConsent !== true) {
    return { ok: false, code: "profile_consent_required", message: "Research consent is required" };
  }
  const profile = normalizeResearchProfile(input.profile);
  if (!profile.ok) return profile;
  return { ok: true, operation, profile: profile.value };
}

export function profileAnswerCoverage(profile: ResearchProfile): {
  meaningfulAnswerCount: number;
  refusalCount: number;
  unansweredCount: number;
  hasMeaningfulAnswer: boolean;
} {
  const fields: Array<keyof ResearchProfile> = [
    "learningGoal",
    "englishLevel",
    "ageGroup",
    "lifeStage",
    "gender",
  ];
  let meaningfulAnswerCount = 0;
  let refusalCount = 0;
  let unansweredCount = 0;
  for (const field of fields) {
    const value = profile[field];
    if (value == null) unansweredCount += 1;
    else if (value === "prefer_not_say") refusalCount += 1;
    else meaningfulAnswerCount += 1;
  }
  return {
    meaningfulAnswerCount,
    refusalCount,
    unansweredCount,
    hasMeaningfulAnswer: meaningfulAnswerCount > 0,
  };
}
