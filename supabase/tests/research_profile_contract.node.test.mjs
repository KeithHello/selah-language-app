import assert from "node:assert/strict";
import { test } from "node:test";

const {
  PROFILE_NOTICE_VERSION,
  PROFILE_OPERATIONS,
  PROFILE_ENUMS,
  normalizeResearchProfile,
  validateProfileOperation,
  profileAnswerCoverage,
} = await import("../functions/_shared/research_profile_contract.ts");

test("normalizes optional profile values without inventing answers", () => {
  const result = normalizeResearchProfile({
    learningGoal: "work",
    englishLevel: null,
    ageGroup: "prefer_not_say",
    lifeStage: undefined,
    gender: "self_described",
    genderDescription: "非二元",
  });

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(result.value, {
    learningGoal: "work",
    englishLevel: null,
    ageGroup: "prefer_not_say",
    lifeStage: null,
    gender: "self_described",
    genderDescription: "非二元",
  });
});

test("rejects unknown values and overlong self-described gender atomically", () => {
  const invalidEnum = normalizeResearchProfile({ learningGoal: "growth" });
  assert.equal(invalidEnum.ok, false);
  if (!invalidEnum.ok) assert.equal(invalidEnum.code, "profile_invalid_input");

  const invalidLength = normalizeResearchProfile({
    gender: "self_described",
    genderDescription: "😀".repeat(41),
  });
  assert.equal(invalidLength.ok, false);
  if (!invalidLength.ok) {
    assert.equal(invalidLength.code, "profile_invalid_input");
  }
});

test("requires explicit notice and consent only when saving answers", () => {
  const save = validateProfileOperation({
    operation: "save",
    profile: { learningGoal: "daily" },
    noticeVersion: PROFILE_NOTICE_VERSION,
    researchConsent: false,
  });
  assert.equal(save.ok, false);
  if (!save.ok) assert.equal(save.code, "profile_consent_required");

  const skip = validateProfileOperation({ operation: "skip" });
  assert.equal(skip.ok, true);

  const offer = validateProfileOperation({ operation: "offer" });
  assert.equal(offer.ok, true);
  assert.deepEqual(PROFILE_OPERATIONS, ["offer", "save", "skip", "withdraw"]);
});

test("coverage distinguishes meaningful answers, refusals, and untouched fields", () => {
  const coverage = profileAnswerCoverage({
    learningGoal: "work",
    englishLevel: "prefer_not_say",
    ageGroup: null,
    lifeStage: "prefer_not_say",
    gender: null,
    genderDescription: null,
  });
  assert.deepEqual(coverage, {
    meaningfulAnswerCount: 1,
    refusalCount: 2,
    unansweredCount: 2,
    hasMeaningfulAnswer: true,
  });
});

test("keeps the stable enum contract small and explicit", () => {
  assert.deepEqual(PROFILE_ENUMS.learningGoal, [
    "work",
    "daily",
    "travel",
    "exam",
    "other",
    "prefer_not_say",
  ]);
  assert.ok(PROFILE_ENUMS.ageGroup.includes("under_14"));
  assert.ok(PROFILE_ENUMS.gender.includes("self_described"));
});
