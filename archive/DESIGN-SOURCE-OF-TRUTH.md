# Selah Design Source Of Truth

> Date: 2026-07-04
> Current product direction: v8 automatic recommendation Selah.

## Read First

1. `selah-v8-unified-design-spec.md`
   - The current source of truth.
   - Use this for product scope, learning loop, pet rules, IA, and development readiness.

2. `selah-v8-ios-architecture.md`
   - Current v8 development architecture draft.
   - Use this for iOS app layers, backend boundaries, AI/audio flow, use cases, and API planning.

3. `selah-v7-prototype-audit.md`
   - Historical audit of the v7 prototype direction.
   - Use only as background when checking what changed from v7 to v8.

4. `selah-prototype-v8.html`
   - Current high-fidelity interaction prototype.
   - Use as experience reference, not as production architecture.

## Current Prototype

- `selah-prototype-v8.html`

Status:

- Suitable as v8 experience reference.
- Still simulated.
- Product-scope cleanup applied: Japanese is marked as later, Day/streak-like copy is removed, Today Sentence has a Chinese confirmation step, and sprite copy no longer implies XP/evolution.
- MVP vocabulary-help direction is selected: balanced approach with light system suggestions, light behavior-based hide/show, and manual re-show by the user.
- V8 engineering architecture draft has been added in `selah-v8-ios-architecture.md`.
- Still needs concrete implementation choices for minimum iOS version, backend stack, AI/TTS providers, privacy policy, and deployment.

## Historical References

These files contain useful thinking but are not v8 source of truth:

- `selah-v7-unified-design-spec.md`
- `selah-prototype-v7.html`
- `language-island-prd.md`
- `language-learning-system-design.md`
- `selah-engineering-kickoff.md`
- `pet-system-design.md`
- `selah-architecture.html`
- `selah-v6-review.html`
- `selah-v6-deep-review.html`
- `selah-vocab-analysis.html`
- `selah-prototype-v4.html`
- `selah-prototype-v5.html`
- `selah-prototype-v6.html`

Use them only for background rationale.

## Historical Ideas Kept In V8

- Learning starts from the user's real-life sentences.
- Night preview lowers next-day listening friction.
- Listen before output.
- Predict before reveal.
- Lightweight sentence deconstruction.
- Shadowing.
- Self-rated recall.
- Vocabulary stays attached to sentences.
- Sprite is gentle and non-punitive.
- iOS-native 2-tab/push navigation.

## Historical Ideas Retired For V8

- Visible XP.
- Streak count.
- Four pet dimensions: Hunger / Mood / Health / Bond.
- Pet death / rebirth / rescue tasks.
- Complex evolution stages and thresholds.
- Smart Excel as visible L0-L5 system.
- Five-tab navigation.
- Coverage radar.
- Separate Daily Win / Goodnight feature.
- Separate Clinking feature.
- Heavy voice selection during onboarding.
- Standalone vocabulary drill mode.

## Development Rule

If any older document conflicts with `selah-v8-unified-design-spec.md`, follow `selah-v8-unified-design-spec.md`.
