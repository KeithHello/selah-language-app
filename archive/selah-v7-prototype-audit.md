# Selah v7 Prototype Audit

> Date: 2026-07-02
> Audited file: `selah-prototype-v7.html`
> Standard: `selah-v7-unified-design-spec.md`

## Executive Conclusion

The current v7 prototype is directionally suitable for the minimal Selah product.

It successfully demonstrates the right product shape:

- 2-tab IA.
- Today-first daily ritual.
- Push-style learning flows.
- Listen -> predict -> deconstruct -> shadow.
- Flip-card recall practice.
- Chinese daily sentence -> English learning material.
- Vocabulary as a sentence byproduct.
- Sprite as gentle emotional companion.

However, the prototype is not yet a complete development blueprint. Product-scope cleanup has been applied after this audit: Japanese is now marked as later, Day/streak-like copy has been softened, Today Sentence includes a Chinese confirmation step, and sprite copy no longer implies XP/evolution. Remaining gaps are mostly engineering-definition gaps: persistence, review scheduling, real STT, real translation, real TTS, and what "completed" means in data.

## 1. Scope Audited

Reviewed:

- Onboarding.
- Today screen.
- Notes screen.
- Listen flow.
- Practice flow.
- Night Preview.
- Today Sentence recording flow.
- JavaScript interactions and simulated data.
- Consistency with v7 direction and older design documents.

Not audited:

- Real visual screenshots across devices.
- Accessibility through screen reader or keyboard testing.
- Real STT, AI translation, TTS, persistence, push notification, widget, or iOS implementation.

## 2. What Is Working Well

### 2.1 The product has become understandable

The v7 prototype is much clearer than the older broad PRD direction. A user sees:

- Today.
- Listen.
- Practice.
- Night Preview.
- Today Sentence.
- Notes.

This is close to the "less than five core concepts" goal. The app no longer feels like a dashboard of systems.

### 2.2 The learning science is still present

The earlier learning method is not lost. The prototype keeps the important pieces:

- User-owned life sentences.
- Preview before listening.
- Listening before seeing English.
- Prediction before reveal.
- Sentence deconstruction before shadowing.
- Recall practice after exposure.

This is the right compromise: simpler product surface, but still grounded in the original learning design.

### 2.3 The listen flow is the strongest part

The four-step flow is coherent:

```text
Listen -> Predict -> Deconstruct -> Shadow
```

The locked-step progression inside one session is appropriate. It protects the learning method without making the whole app feel rigid.

### 2.4 Vocabulary direction is correct

The prototype treats vocabulary as contextual:

- Words appear inside preview and deconstruction.
- The vocabulary list explains that words are accumulated naturally.
- Recording feedback encourages active use.

This matches the v7 vocabulary philosophy.

### 2.5 The sprite tone is mostly right

The sprite is warm, encouraging, and non-punitive. It does not show XP, death, hunger, or health bars in v7. That is aligned with the minimal direction.

## 3. UX And Product Risks

### Risk 1: Japanese is selectable, but the prototype is English-only

Status after cleanup: mitigated in prototype. Japanese is now shown as a disabled "later" option.

The onboarding allows English and Japanese selection, but the rest of the prototype content and learning logic are English.

Why it matters:

- If development starts from this, engineering may overbuild language abstraction too early.
- Users may expect Japanese content that does not exist.

Recommendation:

- For v7 MVP, either remove Japanese from onboarding or label it as "coming later".
- Keep architecture language-ready, but do not make the first user experience bilingual.

Severity: Medium.

### Risk 2: "Day 8" and progress text are hardcoded

Status after cleanup: fixed in prototype. Day/streak-like visible copy has been removed from Today and sprite diary copy.

The prototype repeatedly says Day 8, 13 sentences, 4 mastered, 2/5 listening, and similar numbers.

Why it matters:

- V7 explicitly avoids streak pressure and visible progress gamification.
- Day count can behave like a streak even if it is not called one.

Recommendation:

- Replace visible day count with contextual language:
  - "今天可以先聽兩句"
  - "你最近收集了幾句自己的英文"
  - "小豆今天很想聽你說一句"
- If the app needs day-based internal state, keep it private.

Severity: High for product tone.

### Risk 3: The sprite still implies growth/unlock mechanics

Status after cleanup: fixed in prototype. Sprite copy now uses soft reactions rather than unlock/progression language.

The prototype mentions "解鎖新動作", "連續 7 天", "羽毛更亮", and similar progression language.

Why it matters:

- This can slowly pull the product back toward XP/evolution design.
- The sprite should reflect presence, not become a reward ladder.

Recommendation:

- Keep micro-animation changes, but describe them as soft reactions rather than unlocks.
- Avoid "continuous days" and "unlock" language in user-facing copy.

Severity: Medium.

### Risk 4: Review scheduling is not defined enough for development

The Practice flow works as a prototype, but engineering still needs rules for which sentences appear.

Why it matters:

- If not defined now, the team may accidentally reintroduce Smart Excel L0-L5 or build a random quiz queue.
- Learning effectiveness depends on recall timing.

Recommendation:

- Use the simplified internal model from the unified spec:
  - `new`
  - `learning`
  - `familiar`
  - `quiet`
- Map self-ratings to next review timing, but never show spreadsheet labels.

Severity: High for development readiness.

### Risk 5: Today Sentence needs a confirmation step

Status after cleanup: fixed in prototype. The flow now pauses on Chinese transcript confirmation before showing AI translation.

The prototype simulates STT and translation, but the production flow must allow the user to confirm/edit the Chinese transcript before saving.

Why it matters:

- Bad transcript -> bad translation -> polluted learning material.
- Older PRD correctly identified this risk.

Recommendation:

- Production flow:
  1. Record or type Chinese.
  2. Confirm/edit Chinese.
  3. Generate English.
  4. Confirm/save.

Severity: High for learning quality.

### Risk 6: Night Preview may become too passive

The current preview lets users read sentences and click words. That is good. But there is no clear "I understand this enough for tomorrow" check beyond a completion button.

Why it matters:

- Preview should reduce next-day listening friction, not become skimming.

Recommendation:

- Keep it minimal, but add one small check:
  - "我大概懂了"
  - optional "這句明天再看"
- Do not add tests to Night Preview.

Severity: Low to Medium.

### Risk 7: Coach hints are useful but may become too text-heavy

The prototype has helpful coach hints in Listen, Practice, and Today Sentence.

Why it matters:

- V7 says users should not need human instruction.
- Too many visible hints can make the app feel explanatory.

Recommendation:

- Keep hints for first 3-5 uses.
- Auto-hide after completion.
- Use shorter copy where possible.

Severity: Medium.

### Risk 8: Notes screen risks becoming a management surface

Notes currently includes many categories, sentence states, vocabulary, and history. It is useful, but close to becoming dense.

Why it matters:

- V7 says Notes is memory/reference, not the main workflow.

Recommendation:

- Keep Notes secondary.
- Search and category filter are enough.
- Do not add analytics, coverage radar, decks, or detailed mastery levels.

Severity: Medium.

## 4. Accessibility Risks

These are visible or likely from the prototype code and layout.

1. Many clickable controls are `div` elements with `onclick`; native implementation should use real buttons and accessible labels.
2. Emoji-only icons need labels in iOS accessibility.
3. Lock/unlock state changes need VoiceOver announcements in native implementation.
4. Small text sizes around 9-11px in the HTML prototype may be too small for production.
5. The Listen flow uses timed delays. Production should not require users to react within fixed time windows.
6. Color alone should not indicate state; pair with text or icon.

These do not block design approval, but they must be part of iOS implementation requirements.

## 5. Does It Match The V7 Goal?

### Goal: help users learn English with their own life sentences

Status: matches.

Evidence:

- Today Sentence creates a Chinese sentence and turns it into English.
- Listen, Preview, Practice, and Notes all revolve around sentence material.

Main gap:

- Real AI/STT/TTS and persistence are not implemented yet.

### Goal: make learning flow effective

Status: mostly matches.

Evidence:

- The flow keeps preview, listening, prediction, deconstruction, shadowing, and recall.

Main gap:

- Review scheduling is now specified in `selah-v7-unified-design-spec.md`; engineering still needs to implement it in persistence and queue selection.

### Goal: use pet system to support learning

Status: matches the v7 pet direction, with copy risks.

Evidence:

- The sprite is warm and visible.
- No XP/status bars appear in v7.

Main gap:

- Day count, unlock language, and "continuous days" copy should be softened.

### Goal: remain minimal

Status: mostly matches.

Evidence:

- 2 tabs.
- Main actions are few.
- Vocab is not a separate drill.

Main gap:

- Notes and coach hints need restraint.
- Japanese should not appear as a fully supported choice unless implemented.

## 6. Development Readiness

The concept is ready to become an implementation plan after the following decisions are locked:

1. English-only MVP, Japanese reserved.
2. No visible XP, no streak, no four-stat pet system.
3. Simplified internal review model, not Smart Excel UI.
4. Today Sentence includes transcript confirmation.
5. Sprite behavior rules use emotional states, not growth economy.
6. Seed content and user-generated content transition rules are defined.
7. MVP vocabulary-help policy is locked to the balanced approach: light system suggestions + light behavior-based hide/show rules + manual re-show.

## 7. Recommended Changes Before Development

### Must fix before engineering starts

1. Create one source of truth: use `selah-v7-unified-design-spec.md`. Done.
2. Mark older PRD and engineering kickoff as historical unless rewritten for v7. Done in `DESIGN-SOURCE-OF-TRUTH.md`.
3. Decide Japanese visibility in onboarding. Done for prototype: disabled "later" option.
4. Define internal review scheduling. Done in unified spec; engineering should implement it as private data rules.
5. Define Today Sentence confirmation and save flow. Done for prototype; engineering still needs persistence details.
6. Remove visible Day 8 / streak-like copy from the product spec. Done for prototype.

### Should fix in the prototype before using it as implementation reference

1. Replace "Day 8" and "連續" language with softer context copy. Done.
2. Remove "解鎖" language from sprite stories. Done.
3. Make Night Preview sentence count match v7 scope: 3-5. Already matches at 5 sentences.
4. Clarify that Practice uses only previously listened sentences. Already present in Today row copy.
5. Shorten coach hints. Still recommended before final visual QA.
6. Decide whether Japanese button is hidden or labeled future. Done: labeled later and disabled.

### Can wait until iOS implementation

1. Haptics.
2. Widget.
3. VoiceOver details.
4. Real audio caching.
5. Real AI quality evaluation.

## 8. Final Product Judgment

The v7 prototype is a good direction and is aligned with the real goal: practical spoken English learning through personal sentences, supported by a gentle sprite.

It is not overbuilt, and it has kept the original learning method where it matters.

The main danger now is not the prototype itself. The danger is letting old documents reintroduce complex systems during development. Development should proceed only from the unified v7 spec, with older materials used as idea references.

At the product-definition level, the major open vocabulary question is now resolved: MVP should use the balanced approach rather than a heavy word-state management system.
