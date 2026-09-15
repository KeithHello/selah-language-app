import assert from "node:assert/strict";
import { test } from "node:test";

const {
  TRIAL_STATES,
  trialStateFromMembership,
  isTrialWindowOpen,
} = await import("../functions/_shared/membership_contract.ts");

test("maps missing dates to preparing instead of active", () => {
  assert.equal(
    trialStateFromMembership({ plan: "trial", status: "trial", started_at: null, expires_at: null }),
    "preparing",
  );
  assert.equal(
    trialStateFromMembership({ plan: "trial", status: "trial", started_at: "2026-09-12T00:00:00Z", expires_at: "2026-09-19T00:00:00Z" }),
    "active",
  );
  assert.equal(
    trialStateFromMembership({ plan: "trial", status: "trial", periodStartsAt: "2026-09-12T00:00:00Z", periodEndsAt: "2026-09-19T00:00:00Z" }),
    "active",
  );
  assert.deepEqual(TRIAL_STATES, ["not_started", "preparing", "active", "expired", "unavailable"]);
});

test("uses a half-open server window for active trial access", () => {
  const start = new Date("2026-09-12T00:00:00Z");
  const end = new Date("2026-09-19T00:00:00Z");
  assert.equal(isTrialWindowOpen(start, end, new Date("2026-09-12T00:00:00Z")), true);
  assert.equal(isTrialWindowOpen(start, end, new Date("2026-09-19T00:00:00Z")), false);
});
