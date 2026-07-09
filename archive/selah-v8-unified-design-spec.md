# Selah v8 Unified Design Spec

> Status: source of truth for development planning.
> Date: 2026-07-04
> Basis: v8 automatic recommendation direction. Older PRD, system-design, pet-system, architecture, and v4-v7 prototype files are historical references unless this document explicitly keeps a mechanism.

## 1. Product Goal

Selah is an iOS-first minimal language learning app for Traditional Chinese speakers learning spoken English first, with Japanese reserved for later.

The product goal is:

> Help users turn their own real-life Chinese sentences into natural English they can hear, understand, recall, and eventually say, while a gentle language sprite gives emotional companionship without pressure.

Selah is not a course app, not an Anki clone, not a pet simulator, and not a productivity streak tracker.

## 2. Target User And Core Problem

Primary user:

- Traditional Chinese speaker, age roughly 20-35.
- Wants practical spoken English for work, friends, travel, daily life, or self-expression.
- Has often failed because textbook sentences feel irrelevant, first-week friction is high, or they can understand but cannot speak.

Current MVP language context:

- Product UI language: Traditional Chinese.
- Source language for self-expression: Traditional Chinese.
- Target language: English.
- Future framework may support other source-language users, including Japanese-native users learning English, but that is not part of MVP exposure.

Core problems Selah must solve:

1. "I do not know what to learn today."
2. "The sentences I learn are not things I actually say."
3. "I can understand, but I cannot say it out loud."
4. "I lose motivation quickly when the app feels like homework."

## 3. V8 Core Principles

These override earlier documents.

1. Minimal concepts: Today Sentence, Listen, Practice, My Notes, Sprite.
2. Flexible guidance: the app recommends the next suitable action based on time and progress, but it does not make the whole day feel failed if the user only does one small thing.
3. Sprite as emotional mirror: the sprite reflects presence and effort. It is not a four-stat pet simulator.
4. Sentence-first learning: every vocabulary item, review, and practice task stays attached to a sentence.
5. iOS-native interaction: 2 tabs maximum, push navigation for main flows, haptics, widget-ready mental model.
6. Chinese input first: users speak or type Chinese; AI turns it into natural English learning material.

## 4. Core Learning Loop

The v8 loop is:

```text
Chinese life sentence
  -> natural English translation
  -> night preview
  -> listen / predict / deconstruct / shadow
  -> quiz recall
  -> use words again in a new Chinese recording
  -> sentence becomes more familiar
```

The product succeeds if a user can repeatedly move sentences through this loop with low friction.

### Product-Level Learning Flow Principle

The user should not need to consciously manage the learning method.

Selah should feel like:

> I follow the next small thing the app suggests, and my own sentences naturally come back at the right time.

Internally, the system still follows the learning loop:

```text
Today Sentence -> Night Preview -> Listen -> Practice -> Reuse
```

But the user-facing experience should not feel like a curriculum diagram or task management system.

User-facing principle:

- Show one clear next action.
- Explain why it matters in plain, warm language.
- Keep optional entries available, but visually secondary.
- After each action, tell the user where the sentence will go next.

Examples:

- After `Today Sentence`: "這句之後會回到預覽和聆聽裡."
- After `Night Preview`: "明天聆聽時，小豆會把這些句子帶回來."
- After `Listen`: "之後會在練習裡把它叫回來."
- After `Practice`: "卡住的句子會再陪你聽一次."

This is the v8 learning philosophy:

> Do not ask the user to understand the system. Let the system quietly carry the user's sentences forward.

## 5. Information Architecture

V8 uses 2 tabs.

### Tab 1: Today

Purpose: daily ritual and next action.

Contains:

- Sprite.
- Time-aware greeting.
- Smart recommendation.
- Lightweight learning-flow card.
- Listen entry.
- Practice entry.
- Night Preview entry.
- Today Sentence entry.

Main flows use push navigation, not modal sheets.

Today hierarchy:

1. Primary next action: what the user should do now.
2. Recommendation reason preview: why this next step is useful now.
3. Optional manual entries: Listen, Practice, Night Preview, Today Sentence.

The manual entries are still useful, but they should be visually secondary and collapsed by default. The main mental model is "follow the next step."

Preferred Today surface:

- One primary card: "下一步".
- A small "為什麼是這一步？" area showing 2-3 sentence reasons.
- A collapsed manual control such as "自己選學習內容".

The user should feel that Selah is arranging the learning route for them, while still keeping manual control available when they intentionally look for it.

### Today Recommendation Rules

Today should be state-first, time-assisted.

The app should not primarily recommend based on "morning = Listen, afternoon = Practice, evening = Preview".

Instead, choose the next action by sentence state:

```text
1. practiceReady exists and it is not too late
   -> Practice

2. previewedNotListened exists
   -> Listen

3. evening + previewReady exists
   -> Night Preview

4. todaySentenceMissing or contentPoolLow
   -> Today Sentence

5. fallback
   -> Seed Listen
```

Definitions:

- `practiceReady`: the user has listened to the sentence before, enough time has passed, and it is useful to recall it now.
- `previewedNotListened`: the sentence was seen in Night Preview but has not yet been listened to.
- `previewReady`: the sentence is suitable for a light preview before future listening.
- `todaySentenceMissing`: the user has not created a self-expression sentence today.
- `contentPoolLow`: the system does not have enough suitable personal sentences for tomorrow or future listening.

Time is still useful, but only as context:

- Late night can raise the priority of Today Sentence or Night Preview.
- Lunch / afternoon can make Practice feel more natural.
- Morning / commute can make Listen feel more natural.
- These should not override a strong sentence-state need.

User-facing recommendation copy must explain the reason:

- Practice: "有 3 句之前聽過，現在剛好可以回想一下."
- Listen: "這幾句已經有點熟了，現在讓耳朵接上."
- Night Preview: "先看一眼就好，明天聽起來會更輕鬆."
- Today Sentence: "它會變成之後會聽、會練的英文."

### Recommendation Reason Preview

The "為什麼是這一步？" area is not a task list.

Purpose:

- Help the user understand why the app is recommending the next action.
- Reassure the user that their sentences are being carried forward.
- Make the automatic system feel trustworthy without exposing internal scheduling complexity.

It should show only 2-3 items.

Each item should include:

- the source sentence or short title
- the next natural state, such as `現在`, `稍後`, `今晚`, `明天`
- a plain-language reason, such as:
  - `之前聽過，現在剛好叫回來`
  - `昨晚看過了，等你聽一次`
  - `今晚先看一眼，明天會更好聽懂`

It should not show:

- internal state names
- exact due dates
- scores
- queues
- abstract care/scheduling language that the user has to learn
- workload totals

If this area feels confusing in user testing, reduce it further to a one-line reason under the primary next-action card.

### Extensible Session Principle

Do not classify users as light / medium / heavy learners during onboarding.

Every learning flow should follow the same interaction pattern:

```text
small default amount
  -> gentle completion point
  -> "先到這裡"
  -> optional "再來一點"
```

This lets the same product support different energy levels without asking the user to choose a fixed learning identity.

MVP application:

- Listen: one sentence at a time. After a sentence, allow `下一句` or `先到這裡`.
- Practice: 3 sentences per set. After a set, allow `再練 3 句` or `先到這裡`.
- Today Sentence: save one sentence at a time. After saving, allow `再留一句` or `先到這裡`.
- Night Preview: show 3-5 sentences per batch. After a batch, allow `我還想再看幾句` or `可以了，明天再聽`.
- The "continue" action should remain available repeatedly. Do not make it a one-time extension.

The system still controls scheduling quality:

- Do not flood tomorrow with every sentence a heavy user created today.
- Keep review queues prioritized by due state and recent difficulty.
- If a user struggles repeatedly, prefer returning sentences to Listen instead of continuing to test them.
- If the user keeps extending naturally, keep offering another small batch rather than switching to a heavy dashboard or forcing a mode change.

User-facing principle:

> Start small. Stop anytime. Continue with one tap.

### Contextual Learning Sets

V8 should use contextual sets, not fixed daily schedules.

A contextual set is a small learning segment that starts from the user's current sentence state and may naturally offer one adjacent action after completion.

The app should not force a rigid sequence such as:

```text
Listen 5 sentences -> Practice 3 sentences -> Preview 3 sentences
```

Instead, the app should recommend the best current entry point, then offer a soft bridge only when it makes learning sense.

Examples:

```text
previewedNotListened exists
  -> Recommend Listen
  -> User listens through a small set
  -> If there are suitable listened sentences, offer "順手練 3 句"
  -> Also offer "再聽一組" and "先到這裡"

practiceReady exists
  -> Recommend Practice
  -> User recalls 3 sentences
  -> If several were weak, return them to Listen later
  -> If the user wants more, offer another 3-sentence practice set

evening + previewReady exists
  -> Recommend Night Preview
  -> User previews 3-5 sentences
  -> Offer "我還想再看幾句" or "可以了，明天再聽"

contentPoolLow or todaySentenceMissing
  -> Recommend Today Sentence
  -> User saves one own sentence
  -> Offer "還有一句想說" or "先到這裡"
```

The bridge should be optional and phrased gently.

Good bridge copy:

- `如果現在還有一點力氣，可以順手把剛才的句子叫回來。`
- `累了也可以停在這裡，這些句子之後會再回來。`
- `想繼續的話，再接一小組就好。`

Avoid:

- mandatory auto-advance into a different mode
- visible curriculum names
- daily quotas
- "complete all steps" pressure
- fixed user labels such as light / medium / heavy learner

Homepage recommendation cards may show a tiny three-step preview of the current contextual set, for example:

```text
先聽 3 句 -> 順手練 3 句 -> 累了就停
```

This preview is only a comfort cue. It is not a commitment that the user must finish every step.

### Tab 2: Notes

Purpose: memory and reference.

Contains:

- My sentences with category filters.
- Vocabulary reference list.
- Lightweight search.

Notes is not the main learning surface. It should not become a second app.

### Tab 2 補充定義（繁體中文開發基準）

`筆記` 的角色不是第二套學習系統，而是：

- 回看自己真的會說的句子
- 在需要時重新看到目前還卡住的詞
- 留下少量、真實、能鼓勵開口的學習足跡

MVP 的筆記頁面建議分成三塊：

1. `我的句子`
2. `生詞`
3. `小豆的回憶`

其中：

- `我的句子` 仍然是主體，因為 Selah 是句子優先學習。
- `生詞` 在首頁只顯示摘要，並提供 `查看全部`。
- `小豆的回憶` 在首頁只顯示少量近期內容，並提供 `查看全部`。

MVP 不要做：

- 厚重的詞庫分類系統
- 很多維度的篩選器
- 成就牆、徽章牆、等級牆
- 獨立於句子的單詞練習模式

### 生詞區資訊架構（MVP）

生詞首頁摘要只保留兩組：

- `仍在關注`
- `已比較熟`

這兩組比 `new / learning / familiar / owned` 更適合顯示給使用者，因為：

- 更接近使用者當下的感受
- 不要求使用者理解系統狀態機
- 保持產品表面簡單

`查看全部` 後的完整頁 / modal 仍然只使用這兩組，不再增加更多分類。

每個生詞項目建議只顯示：

- 英文詞 / 詞組
- 繁體中文意思
- 來源句子
- 一個很輕的狀態提示，例如：
  - `句子拆解中`
  - `下一次還想再看`
  - `你已經用出來過`
  - `不再主動拆解`

不要顯示：

- 分數
- 熟練度條
- 等級
- 複雜日期表
- 使用者需要手動維護的多重標籤

### 小豆的回憶資訊架構（MVP）

`小豆的回憶` 可以理解成「陪伴式學習足跡」。

MVP 可以把它設計成一份完整的回憶清單，數量可先落在 `24 - 30` 個左右。

顯示方式建議：

- 已發生的正常顯示
- 尚未發生的先以灰色顯示
- 不用做稀有度、分數、升級條
- 以「學習歷程」而不是「競爭成就」的語氣來寫

它應該記錄的是：

- 第一次盲聽猜對
- 第一次把學過的詞自然說出來
- 某個曾經需要提示的詞，後來回到句子裡不再需要拆解
- 某句話從卡住到比較順口

它不應該記錄的是：

- 純簽到
- 純打卡
- 跟學習品質無關的累積數字

建議分組方式：

- `開始了`
- `聽懂了`
- `拆開來懂`
- `說出口了`
- `越來越像自己`

這樣可以在內容很多時，仍然保持閱讀上的安定感與方向感。

一句話原則：

> 回憶是為了讓使用者感受到「我真的比以前更敢開口了，而且前面還有很多自然會發生的進步」，不是為了增加壓力。

## 6. Screen Requirements

### Onboarding

Must let the user:

- Choose target language. For v8 development, English is the only production target; Japanese can be visible only if the team is ready to explain it as future / preview.
- Name the sprite.
- Pick 3 seed sentences or themes.
- Hatch the sprite.

Risk to avoid:

- Do not ask for voice selection, goals, levels, schedules, and topic preferences all at once. That recreates first-week friction.

### Today

Must answer:

- What should I do now?
- How is my sprite feeling?
- Can I enter one useful learning action in one tap?

Today should not show:

- XP.
- Streak count.
- Multi-stat bars.
- Level names.
- Punitive warning states.

### Listen

The learning flow is still four lightweight cognitive steps:

1. Listen: user hears the sentence before seeing English.
2. Predict: user tries to guess or mentally form the English.
3. Deconstruct: app reveals English with 2-3 useful phrases or patterns.
4. Shadow: user speaks and then hears the native/reference audio.

Important nuance:

- The UI should not present these as four heavy locked sections.
- The preferred v8 interaction is a single immersive sentence card that naturally changes state.
- The user should feel like the sentence is slowly unfolding, not like they are passing checkpoints.
- The Today page is flexible, but the Listen session itself can still guide the user through this micro-sequence. This is not a contradiction. Flexibility applies to the daily plan; sequence applies inside a single learning task.
- Deconstruct is scene-first, not grammar-first. Its main job is to help the user understand how to say this scene naturally, not to turn the screen into a mini grammar lesson.
- In practice, deconstruct should usually contain:
- 1-2 still-unfamiliar words or phrases that block understanding or production
- 1 reusable scene pattern when that pattern is especially helpful

Preferred v8 Listen interaction:

```text
Play audio
  -> quiet thinking moment
  -> reveal English in the same card
  -> tap only the highlighted unfamiliar words
  -> follow the reference audio once
  -> complete sentence / next sentence
```

User-facing tone:

- Avoid "unlock" language where possible.
- Avoid making prediction feel like a test.
- Use copy such as "想到幾個詞也可以" instead of asking for a perfect answer.
- Let "deconstruction" appear as lightweight inline help after English is revealed.
- Treat shadowing as a safe try, not pronunciation grading.

### Practice

Practice is a flip-card recall flow:

```text
Chinese sentence -> recall English -> reveal -> self-rate
```

Self-rating options:

- Remembered clearly.
- Almost.
- Could not recall.

Practice should prioritize sentences the user has already listened to. It should not introduce totally unseen sentences.

Practice dosage:

- Default MVP unit: `3 sentences per set`.
- One set should feel finishable in about 3-5 minutes.
- The product should never imply that only 3 sentences can be practiced per day.
- After one set, users may continue into another 3-sentence set.

This supports two user types at the same time:

- Low-energy or easily discouraged users can complete one small set and still feel successful.
- Highly motivated users can continue through multiple sets without needing a separate advanced mode.

Suggested daily guidance:

- Casual day: 1 set, about 3 sentences.
- Focused 30-minute session: 3-5 sets, about 9-15 sentences, mixed with Listen or Today Sentence.
- Longer 60-minute+ session: continue in loops, but the app should insert pauses and vary tasks instead of showing endless recall cards.

Do not make the primary Today UI look like a study timer or workload dashboard. The extended path should appear only after the user finishes a small unit.

### Night Preview

Purpose:

- Reduce next-day listening friction by letting the brain pre-load meaning.

V8 scope:

- 3-5 sentences is acceptable for minimal prototype and early development.
- The older 8-10 sentence plan is not required for v8. It can return later if engagement data supports it.

Night Preview vocabulary behavior:

- The card header should combine index and source sentence in one line, for example `1 · 今天忙死了，老闆又改需求了`.
- English appears below the source sentence.
- System may lightly mark 1-2 high-value words or phrases per card.
- The user may tap a marked word or phrase to add it into vocabulary focus.
- After tapping, the card should immediately show the meaning used in this sentence.
- Night Preview should show only the in-sentence meaning, not every dictionary meaning.
- Broader meanings can live in the vocabulary detail view later, with the in-sentence meaning shown first.

Night Preview learning position:

- Goal: make tomorrow's sentence feel familiar enough to hear.
- Not goal: fully teach every word tonight.
- Keep explanations short and local to the sentence.

### Today Sentence

Purpose:

- Let the user say one Chinese sentence from today's life.
- Translate it into natural, speakable English rather than literal word-by-word English.
- Extract useful vocabulary as feedback.
- Save it so tomorrow's learning is personal.

This replaces the older "Daily Win / Goodnight" as a narrower and clearer concept.

Translation priority for `Today Sentence`:

- priority 1: natural English the user could realistically say out loud
- priority 2: preserve the user's real intent and tone
- priority 3: remain close enough to the source meaning that the sentence still feels like "my sentence"

If naturalness and literalness conflict, favor natural speakable English.

## 7. Sprite System

V8 sprite model:

- One sprite.
- One emotional dimension: consistency / presence.
- Visual and copy feedback only.
- No visible numeric score.
- No punishment.
- No death, health, hunger, mood, or bond system.

Allowed sprite feedback:

- More lively after recent learning.
- Quiet but welcoming after absence.
- Small animation after completing listen or practice.
- Subtle visual changes after sustained use.

Not allowed in v8:

- XP.
- Streak count.
- Four-dimensional status bars.
- Death / rebirth / emergency rescue.
- Complex evolution stages.
- Pet-care tasks unrelated to language learning.

Implementation note:

- Engineering may keep a private internal `activityState` or `lastActiveAt` to choose sprite visuals. It must not become a user-facing score system.
- MVP presents one active sprite. The data model may support multiple companions later, but companion selection, companion collecting, or pet shops are not part of the MVP experience.

## 8. Vocabulary System

Vocabulary is a byproduct of sentence learning.

Selected MVP policy:

- Selah uses the balanced approach for vocabulary help.
- The product should combine light system suggestions with light behavior-based hiding/re-showing rules.
- The user can manually add or re-show words, but should not need to manage detailed vocabulary states.

Rules:

- A word or phrase is always tied to a source sentence.
- Users encounter vocabulary in preview, deconstruction, quiz, and future recordings.
- The vocabulary list is a reference index, not a separate drill mode.
- If the user uses a vocabulary item in a later sentence, that is the strongest sign of real ownership.
- In `Today Sentence`, the system may suggest useful words or phrases first, but the user should also be able to tap other words in the generated English sentence and add them manually.
- In sentence deconstruction, only words or phrases that are still considered "not yet familiar" should be expanded with meanings. Familiar words should remain inside the sentence without extra explanation.

### 對使用者顯示的繁體中文文案層

系統內部可以保留：

- `new`
- `learning`
- `familiar`
- `owned`

但使用者表面原則上不要看到這四個英文狀態。

MVP 對外統一顯示為：

- `仍在關注`
- `已比較熟`

對應方式建議為：

- `new` / `learning` -> `仍在關注`
- `familiar` / `owned` -> `已比較熟`

這樣可以保留系統判斷能力，也不會讓使用者感覺自己在管理一套詞彙資料庫。

Lifecycle:

- `new`: newly added or manually selected word; can appear in preview and deconstruction.
- `learning`: still being surfaced with meaning hints in sentence deconstruction.
- `familiar`: no longer needs inline meaning hints in deconstruction, but still belongs to the sentence and can reappear in quiz or future recordings.
- `owned`: the user has naturally used it in a later sentence; it should stop being treated as active vocabulary help unless the user starts failing on it again.

### Vocabulary State Ownership

The user does not directly choose `new / learning / familiar / owned` as a permanent label.

The system should infer the state from behavior, because Selah is trying to reduce management overhead.

The user is allowed to do only two direct actions:

- add a word or phrase into vocabulary focus
- remove a word or phrase from vocabulary focus for now

Those actions affect what the system pays attention to, but they do not permanently force a mastery state.

### Suggested Word-Level State Rules

This is the selected MVP direction.

It is intentionally light:

- system suggests 1-2 high-value words or phrases
- user may manually add other words from the sentence
- help fades when the user appears comfortable
- help returns when the user starts struggling again

Each vocabulary item should have:

```text
word.status = new | learning | familiar | owned
word.sourceSentenceIds = [...]
word.lastSeenAt = date
word.lastUsedAt = date?
word.manualPinned = boolean
word.manualDismissedAt = date?
word.successCount = integer
word.failureCount = integer
word.activeHelpVisible = boolean
```

Meaning of each state:

- `new`: the word was just added by the system or manually selected by the user, but there is not enough evidence yet that the user remembers it.
- `learning`: the word has been surfaced at least once in preview/deconstruction/quiz and still needs active help.
- `familiar`: the user usually recognizes or recalls it, so inline meaning help is no longer needed by default.
- `owned`: the user has used it naturally in a later self-expression sentence, so the product treats it as part of the user's active language.

### State Transitions

`new -> learning`

Trigger:

- the word is manually selected by the user in Preview or Today Sentence, or
- the system suggests it and the user keeps it, or
- the word is exposed in sentence deconstruction because it is judged important and unfamiliar

Result:

- show meaning hints in deconstruction
- allow it to appear in focused vocabulary suggestions

`learning -> familiar`

Trigger:

- the user sees the word across multiple sentence touches and no longer signals difficulty
- suggested MVP rule: any 2 of the following are enough:
  - the sentence containing it gets `Remembered clearly` twice
  - the user leaves the word unexpanded across 2 later encounters
  - the word appears in quiz context and the sentence is rated `Remembered clearly`

Result:

- stop showing inline meaning by default in sentence deconstruction
- keep the word tied to the sentence and eligible for review

`familiar -> owned`

Trigger:

- the user naturally uses the word or phrase in a later Today Sentence / free recording
- this should be detected either by exact phrase match or a safe semantic match reviewed by the app logic

Result:

- remove it from active vocabulary help
- keep its history and sentence links
- show it in Notes as a word the user has already used

`familiar or owned -> learning`

Trigger:

- the user starts failing on sentences containing the word again
- suggested MVP rule:
  - 2 `Almost` or `Could not recall` outcomes on relevant sentences in a short window, or
  - the user manually re-adds the word to focus

Result:

- show the meaning again in deconstruction
- return it to active help

### What The User Can Choose

The user can choose:

- whether to add a suggested word into focus
- whether to manually add another word from the generated sentence
- whether to re-add a previously familiar word into focus

The user should not need to choose:

- whether a word is `learning` versus `familiar`
- whether a word is `familiar` versus `owned`
- exact spaced-review timing for each word

This keeps Selah supportive instead of turning it into a word-management tool.

### When A Word Still Appears In Deconstruction

Show a word or phrase with inline meaning in sentence deconstruction when:

- `word.status` is `new` or `learning`, and
- the word is relevant to understanding or producing the sentence, and
- the user has not recently dismissed it

Do not show inline meaning by default when:

- `word.status` is `familiar` or `owned`

Even then, the word should still remain tappable if the user wants to inspect it again.

### MVP Judgment Standard For "Needs Explanation"

For MVP, a word or phrase should be treated as currently needing explanation when most of the following are true:

- it blocks understanding of the sentence or blocks saying the sentence naturally
- it is a scene-relevant expression rather than a low-value function word
- it is more useful as a phrase than as an isolated token
- the user has manually added it, kept the system suggestion, or recently struggled on related sentences

For MVP, deconstruction should usually surface:

- at most 1-2 still-unfamiliar words or phrases
- optionally 1 reusable scene pattern when it is especially useful

Do not surface by default:

- basic function words
- every unknown token in the sentence
- grammar explanations unless they directly help produce the scene expression

Avoid:

- Flashcard deck.
- Isolated word memorization.
- Vocabulary levels such as L0-L5 exposed to the user.

## 9. Review And Scheduling

V8 keeps the learning intent of Smart Excel but not its visible complexity.

Keep:

- Self-rated recall.
- Prioritize weak or recently learned sentences.
- Prevent the queue from growing infinitely.

Remove from user-facing v8:

- "Excel" metaphor.
- L0-L5 labels.
- Red / green system language.
- Monthly wake-up terminology.

Suggested internal model:

```text
sentence.reviewState = new | learning | familiar | quiet
sentence.nextReviewAt = date
sentence.recallSignal = clear | almost | failed
```

This preserves spaced practice without making the product feel like a spreadsheet.

### Suggested v8 Review Rules

These rules are intentionally simple enough for MVP engineering.

When a sentence is created:

- `reviewState = new`
- It can appear in Night Preview immediately.
- It should not appear in Practice until the user has completed at least one Listen session for it.

After Listen is completed:

- `reviewState = learning`
- `nextReviewAt = tomorrow`

After Practice self-rating:

| Self-rating | Internal signal | Next state | Next review |
|---|---|---|---|
| Remembered clearly | `clear` | `familiar` | 3 days later |
| Almost | `almost` | `learning` | tomorrow |
| Could not recall | `failed` | `learning` | later today or tomorrow |

If a `familiar` sentence is remembered clearly again:

- Keep `reviewState = familiar`.
- Set `nextReviewAt = 7 days later`.

If a sentence is remembered clearly after the 7-day review:

- Set `reviewState = quiet`.
- It leaves normal daily Practice, but can still appear occasionally in Notes or future mixed review.

If any `familiar` or `quiet` sentence gets `almost` or `failed`:

- Move it back to `learning`.
- Set `nextReviewAt = tomorrow`.

Queue selection:

- Practice should show 3 sentences per set in early v8.
- Prefer due `learning` sentences.
- Then include due `familiar` sentences.
- If there are fewer than 3 due sentences, fill with recently listened sentences.
- After a set is completed, the user may continue into another set if more due or useful sentences are available.

This is the v8 replacement for visible Smart Excel. Do not expose state names, due dates, red/green labels, or levels to users.

## 10. AI And Audio Requirements

V8 requires real AI/audio in production, even if the prototype simulates them.

### Frontend Presentation

AI/audio should be visible enough to build trust, but not heavy enough to become a technical setup flow.

The user-facing flow for Today Sentence should be:

```text
Chinese voice or text input
  -> editable Chinese transcript
  -> natural English generation
  -> English audio generation with the selected voice
  -> save sentence into future preview / listen / practice
```

Frontend should show:

- A microphone entry and editable Chinese text area.
- A confirmation step before translation: `先確認中文`.
- A lightweight generation progress area:
  - `整理你的中文`
  - `轉成可以說出口的自然英文`
  - `產生可以跟讀的英文聲音`
- The generated English sentence.
- A play button for generated English audio.
- The currently selected English voice.

Frontend should not show:

- provider names
- model names
- API latency
- technical pipeline labels such as STT / TTS
- separate setup screens before the user creates the first sentence

### Voice Choice

Voice choice is useful, but it must not recreate onboarding friction.

MVP rule:

- Choose a high-quality default voice automatically.
- Let users adjust voice inside Today Sentence or later Settings.
- Do not ask for voice selection during first onboarding.

Recommended voice options for v8 prototype:

- `溫柔自然`: clear, gentle, default recommendation.
- `清晰慢速`: slower and more separated, useful for beginners.
- `日常輕快`: more casual and conversational.

The selected voice should affect:

- generated audio for newly created Today Sentence entries
- future Listen playback for those newly saved sentences
- shadowing reference audio for those newly saved sentences

The selected voice should not affect:

- translation quality
- vocabulary selection
- review scheduling
- existing audio files by default

Production implementation can map these user-facing voices to actual backend TTS voices. The mapping is internal and should be changeable without changing the user-facing labels.

If the user changes voice later:

- New sentences should use the newly selected voice.
- Existing sentences should keep their original audio.
- Existing sentence audio can be manually regenerated later.
- Manual regeneration is a future credit-relevant action, but MVP should not show credit cost.

STT:

- Accept natural Chinese.
- Preserve meaningful self-corrections.
- Allow manual edit before saving.

Translation:

- Natural spoken English.
- Not textbook-like.
- Slightly above the user's current level, but still usable.
- Consistent phrasing for repeated intent.

TTS:

- Clear, natural pronunciation.
- Speed control for learning.
- Cached per sentence.
- Generated in the background when possible.
- TTS failure must not prevent saving a generated English sentence.

Voice selection:

- Not required during first onboarding for v8.
- A default high-quality voice is acceptable.
- Voice customization can be a later setting if it does not add first-week friction.

### Future Credit Framework

AI and TTS operations have real provider cost, so the architecture should be credit-ready.

MVP rule:

- Do not show credit balance.
- Do not block learning with payment UI.
- Do not make users think about cost during the learning loop.

Future billable operations may include:

- generating a natural English sentence
- generating initial TTS audio
- manually regenerating audio with a different voice
- future advanced AI review or conversation features

The backend may record internal usage units from day one for cost observation, but this must remain invisible to users until a payment model is intentionally introduced.

## 11. Cold Start Strategy

V8 uses two content sources:

- System seed sentences selected from onboarding.
- User-generated sentences from Today Sentence.

Transition:

- Days 1-3: mostly seed content.
- Days 4-7: seed + user-generated mix.
- Day 8 onward: user-generated content should become the center.

Do not expose these phases as labels to the user.

## 12. What To Keep From Older Documents

Keep as core:

- Real-life sentence as the learning origin.
- Pre-input / night preview.
- Listen before output.
- Predict before reveal.
- Lightweight sentence deconstruction.
- Shadowing.
- Self-rated recall.
- Gentle companion sprite.
- iOS-native navigation.
- Vocabulary as contextual byproduct.

Keep only as internal inspiration:

- Spaced repetition from Smart Excel.
- Behavior-signal-driven learning state.
- Six content categories.
- Cold-start seed library.

## 13. What To Retire For V8

Retired for v8 development:

- Visible XP.
- Streak count.
- Pet death / rebirth.
- Hunger / Mood / Health / Bond.
- Complex evolution thresholds.
- Smart Excel labels and full six-level model.
- Five-tab IA.
- Heavy voice selection during onboarding.
- Daily Win / Goodnight as a separate concept.
- Clinking as a separate feature.
- Coverage radar or six-category analytics.
- Micro output challenge as a separate mode.

These may be revisited only after the v8 loop proves retention and learning value.

## 14. Development Readiness Criteria

Before implementation starts, the team should be able to answer yes to these:

1. Can a new user understand the app from Today without reading instructions?
2. Can one sentence travel through recording, preview, listen, practice, and notes?
3. Does the sprite support motivation without creating pressure?
4. Does every vocabulary item stay attached to a sentence?
5. Are old PRD features clearly excluded from v8 scope?
6. Can the first build ship with mock content while leaving clean seams for STT, translation, TTS, persistence, and review scheduling?

Current answer after reviewing the v8 prototype: mostly yes, with the v7 audit kept as historical context.
