# Selah 技術規格書 v1.0

> 數據模型 + API 接口 + 語音選擇方案

---

## 一、語音選擇方案

### 英語聲線（OpenAI TTS `tts-1`）

OpenAI TTS 提供 6 種內建聲線：alloy、echo、fable、onyx、nova、shimmer。從中選出 4 種，對應「美式/英式 × 男/女」組合：

| 用戶選擇 | OpenAI Voice | 特徵描述 | 推薦場景 |
|---------|-------------|---------|---------|
| 🇺🇸 美式女聲 | **nova** | 溫暖、自信、自然。語調平穩偏美式。 | 最通用的選擇，適合大多數用戶 |
| 🇺🇸 美式男聲 | **echo** | 清晰、友好、略帶活力。標準美式發音。 | 喜歡男聲的用戶 |
| 🇬🇧 英式女聲 | **shimmer** | 優雅、柔和、帶輕微英式腔調。 | 偏好英式發音的用戶 |
| 🇬🇧 英式男聲 | **fable** | 沉穩、有質感、帶英式韻律感。 | 偏好英式男聲的用戶 |

**Onboarding 流程中的選擇方式：**

```
Step 1: 語言選擇 → English
Step 2: 發音偏好 → 🇺🇸 美式 / 🇬🇧 英式
Step 3: 聲線性別 → ♀ 女聲 / ♂ 男聲
```

用戶選完後，App 存儲 `voice_id`（如 `nova`），後續所有 TTS 都使用該聲線。用戶可以隨時在設定中切換。

**備選聲線（未來擴展）：**
- **alloy**：中性聲線，不男不女。可作為「中性」選項。
- **onyx**：低沉男聲。可作為「深沉男聲」進階選項。

### 日語聲線（Google Gemini TTS）

Gemini TTS 的日語聲線庫更豐富。建議提供 4 種聲線：

| 用戶選擇 | 聲線類型 | 特徵描述 |
|---------|---------|---------|
| 🇯🇵 標準語女聲 A | 年輕女性・活潑 | 明亮、親切、語調自然。適合日常對話場景。 |
| 🇯🇵 標準語女聲 B | 成熟女性・溫和 | 沉穩、溫柔、有知性美。適合較正式的場景。 |
| 🇯🇵 標準語男聲 A | 年輕男性・清晰 | 清爽、有活力、發音清楚。適合初學者模仿。 |
| 🇯🇵 標準語男聲 B | 成熟男性・沉穩 | 低沉、可靠、語速適中。適合商務日語場景。 |

> 註：日語暫不設「方言」選項（關西弁等）。MVP 只支援標準語。

**日語 Onboarding：**
```
Step 1: 語言選擇 → 日本語
Step 2: 聲線風格 → 活潑 / 溫和（女） 或 清晰 / 沉穩（男）
```

### 語音參數設定

所有聲線共用的參數：

| 參數 | 預設值 | 範圍 | 說明 |
|------|-------|------|------|
| speed | 0.85 | 0.7 - 1.2 | 聆聽預設速度（用戶可在播放時切換） |
| pitch | 0 | -5 到 +5 | 不調整（保持原聲線特質） |

---

## 二、數據模型

### 2.1 User（用戶）

```typescript
interface User {
  id: string;                    // UUID
  email: string;                 // 登入用
  display_name: string;          // 顯示名稱
  created_at: DateTime;          // 註冊時間
  last_active_at: DateTime;      // 最後活躍時間
  streak_days: number;           // 連續天數（由系統計算，不存儲）
  total_days: number;            // 累計使用天數
  
  // Onboarding 狀態
  onboarding_completed: boolean;
  
  // 語言與語音偏好
  learning_language: 'en' | 'ja';       // 學習語言
  accent_preference: 'us' | 'uk';        // 發音偏好（英語時有效）
  voice_id: string;                      // 選定的聲線 ID（如 'nova'）
  voice_gender: 'female' | 'male';       // 聲線性別
  
  // 訂閱
  subscription_tier: 'free' | 'pro';     // 訂閱等級
  daily_recordings_used: number;         // 今日已用錄音次數
  daily_recording_limit: number;         // 每日錄音上限（free=1, pro=∞）
}
```

### 2.2 Pet（精靈）

```typescript
interface Pet {
  user_id: string;               // 關聯用戶
  name: string;                  // 精靈名字（如「小豆」）
  created_at: DateTime;          // 孵化時間
  
  // 外觀（漸進裝飾，非階段進化）
  decoration_stage: 'none' | 'sprout' | 'leaf' | 'bud' | 'bloom';
  // none = Day 1-3（純種子）
  // sprout = Day 4（小葉芽）
  // leaf = Day 7（大葉子）
  // bud = Day 10（花苞）
  // bloom = Day 14+（開花）
  
  // 當前狀態
  current_mood: 'happy' | 'neutral' | 'quiet';
  // happy = 近期活躍
  // neutral = 正常
  // quiet = 缺席多天
  
  last_interaction_at: DateTime; // 最後互動時間
  
  // 動畫狀態（前端計算，不存儲）
  // current_animation: 由前端根據觸發事件實時決定
}
```

### 2.3 Sentence（句子）

```typescript
interface Sentence {
  id: string;                    // UUID
  user_id: string;               // 所屬用戶
  
  // 原始中文（用戶說的）
  zh_original: string;           // STT 辨識結果（保留不完美）
  zh_corrected: string | null;   // 用戶修正後的中文（如有）
  
  // AI 生成的英文
  en_translation: string;        // 教學化翻譯結果
  
  // 音頻
  audio_url: string;             // TTS 生成的音頻 URL（存在 R2/S3）
  audio_duration_ms: number;     // 音頻時長（毫秒）
  voice_id: string;              // 生成時使用的聲線
  
  // 拆解數據（AI 生成）
  deconstruction: Deconstruction;
  
  // 詞彙 metadata
  vocab_candidates: VocabCandidate[];  // AI 標記的可教學詞組
  
  // 分類
  category: SentenceCategory;
  
  // 來源
  source: 'user_recording' | 'system_seed';  // 用戶錄音 or 系統預設
  
  // 生命週期
  created_at: DateTime;          // 錄音時間（Day 0）
  preview_available_at: DateTime; // 夜間預覽開放時間（Day 0 晚）
  listen_available_at: DateTime;  // 聆聽開放時間（Day 1）
  quiz_available_at: DateTime;    // Quiz 開放時間（Day 2）
  mastery_status: 'learning' | 'mastered' | 'needs_review';
}

interface Deconstruction {
  chunks: Chunk[];               // 句子拆解的詞組塊
}

interface Chunk {
  text: string;                  // 詞組文字（如 "iced latte"）
  type: 'phrase' | 'pattern' | 'word';  // 詞組/句型/單詞
  zh_meaning: string;            // 中文釋義
  usage_note: string;            // 用法說明
  difficulty: 'basic' | 'intermediate' | 'advanced';
}

interface VocabCandidate {
  word: string;                  // 詞組（如 "got off on time"）
  meaning: string;               // 中文釋義
  ai_recommended: boolean;       // AI 是否推薦加入
  difficulty: 'basic' | 'intermediate' | 'advanced';
}

type SentenceCategory = 
  | '社畜日常'    // 工作相關
  | '朋友幹話'    // 朋友之間
  | '先吐為快'    // 吐槽發洩
  | '走心時刻'    // 情感表達
  | '表達觀點'    // 觀點想法
  | '生活闖關';   // 日常場景
```

### 2.4 VocabItem（生詞）

```typescript
interface VocabItem {
  id: string;                    // UUID
  user_id: string;               // 所屬用戶
  word: string;                  // 詞組（如 "swamped"）
  meaning: string;               // 中文釋義（如 "忙翻了"）
  
  // 來源追蹤
  source_sentence_id: string;    // 出自哪個句子
  source_sentence_zh: string;    // 來源句子的中文（方便回憶上下文）
  
  // 學習軌跡
  encountered_count: number;     // 在不同句子中遇到的次數
  used_in_recording: boolean;    // 是否在錄音中主動使用過
  used_count: number;            // 在錄音中使用的次數
  
  // 狀態
  mastery: 'new' | 'familiar' | 'mastered';
  // new = 剛加入
  // familiar = 在多個句子中遇到過
  // mastered = 在錄音中主動使用過
  
  created_at: DateTime;          // 加入生詞本的時間
  last_encountered_at: DateTime; // 最後一次在句子中遇到
}
```

### 2.5 Progress（學習進度）

```typescript
interface Progress {
  user_id: string;
  date: string;                  // 日期 YYYY-MM-DD（主鍵之一）
  
  // 聆聽
  sentences_listened: number;    // 當日聆聽句子數
  listen_sessions: number;       // 聆聽次數
  
  // Quiz
  quiz_cards_reviewed: number;   // 當日翻卡數
  quiz_good_count: number;       // 「記得很清楚」次數
  quiz_mid_count: number;        // 「差一點」次數
  quiz_fail_count: number;       // 「完全不會」次數
  
  // 錄音
  recordings_made: number;       // 當日錄音次數
  
  // 生詞
  vocab_added: number;           // 當日新增生詞數
  
  // 連續天數
  is_active_day: boolean;        // 當天是否有學習行為
}

interface StreakInfo {
  current_streak: number;        // 當前連續天數
  longest_streak: number;        // 歷史最長連續
  total_active_days: number;     // 總活躍天數
}
```

### 2.6 SeedSentence（系統種子句）

```typescript
interface SeedSentence {
  id: string;                    // UUID
  zh_text: string;               // 中文句子
  en_translation: string;        // 預翻譯英文
  audio_url: string;             // 預生成音頻 URL
  deconstruction: Deconstruction;
  vocab_candidates: VocabCandidate[];
  category: SentenceCategory;
  difficulty: 'basic' | 'intermediate';
  
  // 種子句主題標籤（onboarding 選擇用）
  seed_tags: string[];           // 如 ['社畜日常', '生活闖關']
}
```

### 2.7 PetMemory（精靈回憶）

```typescript
interface PetMemory {
  id: string;                    // UUID
  user_id: string;
  day_number: number;            // Day N
  memory_type: MemoryType;
  title: string;                 // 標題（如「第一次盲聽猜對」）
  description: string;           // 精靈視角的描述
  icon: string;                  // emoji 圖標
  created_at: DateTime;
}

type MemoryType = 
  | 'time_milestone'             // Day 1/7/14/30/100
  | 'content_milestone'          // 第 10/25/50/100 句
  | 'first_experience'           // 第一次猜對/錄音/用詞
  | 'special_moment'             // 深夜學習/週末不斷更
  | 'vocab_journey'              // 特定詞的使用軌跡
  | 'growth_observation';        // 句子變長/預測變準
```

---

## 三、API 接口規格

### 3.1 認證

```
POST /api/auth/register
  Body: { email, password, display_name }
  Response: { user: User, token: string }

POST /api/auth/login
  Body: { email, password }
  Response: { user: User, token: string }

POST /api/auth/refresh
  Header: Authorization: Bearer <token>
  Response: { token: string }
```

### 3.2 Onboarding

```
POST /api/onboarding/complete
  Header: Authorization: Bearer <token>
  Body: {
    pet_name: string,
    learning_language: 'en' | 'ja',
    accent_preference: 'us' | 'uk',
    voice_id: string,
    voice_gender: 'female' | 'male',
    selected_seed_ids: string[]    // 選中的種子句 ID（最多 3 個）
  }
  Response: { user: User, pet: Pet, initial_sentences: Sentence[] }

GET /api/onboarding/seed-sentences?language=en
  Response: { seeds: SeedSentence[] }
```

### 3.3 錄音 → 翻譯（核心流程）

```
POST /api/recording/upload
  Header: Authorization: Bearer <token>
  Content-Type: multipart/form-data
  Body: {
    audio: File,                  // 錄音文件（AAC/Opus）
    selected_category: SentenceCategory | null  // 用戶選的話題分類
  }
  Response: {
    recording_id: string,         // 錄音 ID（用於後續步驟）
    transcript: string            // STT 辨識結果
  }

POST /api/recording/confirm-transcript
  Header: Authorization: Bearer <token>
  Body: {
    recording_id: string,
    corrected_text: string        // 用戶修正後的中文
  }
  Response: {
    recording_id: string,
    confirmed: boolean
  }

POST /api/recording/translate
  Header: Authorization: Bearer <token>
  Body: {
    recording_id: string,
    voice_id: string              // 使用的聲線
  }
  Response: {
    sentence: Sentence            // 完整的句子數據（含翻譯、拆解、詞彙）
    audio_url: string             // TTS 音頻 URL
  }

POST /api/recording/save
  Header: Authorization: Bearer <token>
  Body: {
    recording_id: string,
    selected_vocab: string[]      // 用戶勾選要加入生詞本的詞組
  }
  Response: {
    sentence: Sentence,
    new_vocab: VocabItem[],       // 新加入的生詞
    toast_message: string         // 前端顯示的提示訊息
  }
```

### 3.4 聆聽

```
GET /api/listen/today
  Header: Authorization: Bearer <token>
  Response: {
    playlist: Sentence[],         // 今日 5 句聆聽句子
    progress: { completed: number, total: number }
  }

POST /api/listen/complete
  Header: Authorization: Bearer <token>
  Body: {
    sentence_id: string,
    listen_count: number,         // 聽了幾遍
    predict_correct: boolean,     // 預測是否大致正確
    shadow_completed: boolean     // 是否完成跟讀
  }
  Response: {
    progress: { completed: number, total: number },
    pet_animation: string         // 建議播放的寵物動畫 ID
  }
```

### 3.5 Quiz

```
GET /api/quiz/today
  Header: Authorization: Bearer <token>
  Response: {
    cards: QuizCard[],            // 今日 3 張 Quiz 卡
    vocab_cards: VocabCard[]      // 生詞卡（0-2 張）
  }

POST /api/quiz/evaluate
  Header: Authorization: Bearer <token>
  Body: {
    card_id: string,
    card_type: 'sentence' | 'vocab',
    result: 'good' | 'mid' | 'fail'
  }
  Response: {
    progress: { reviewed: number, total: number },
    pet_animation: string
  }

interface QuizCard {
  id: string;
  sentence_id: string;
  zh_text: string;               // 中文（正面）
  en_text: string;               // 英文（背面）
  category: SentenceCategory;
  last_reviewed_at: DateTime;
  previous_result: 'good' | 'mid' | 'fail' | null;
}

interface VocabCard {
  id: string;
  vocab_id: string;
  word: string;                  // 英文詞組（正面）
  meaning: string;               // 中文釋義（背面）
  source_sentence_zh: string;    // 來源句子（提示用）
}
```

### 3.6 夜間預覽

```
GET /api/preview/tomorrow
  Header: Authorization: Bearer <token>
  Response: {
    new_sentences: Sentence[],    // 明日新句（2-3 句）
    review_sentences: Sentence[], // 舊句複習（1-2 句）
    is_available: boolean,        // 21:00 後才為 true
    available_at: string          // ISO 時間
  }

POST /api/preview/vocab/add
  Header: Authorization: Bearer <token>
  Body: {
    sentence_id: string,
    word: string,
    meaning: string
  }
  Response: {
    vocab: VocabItem
  }

POST /api/preview/complete
  Header: Authorization: Bearer <token>
  Response: { success: boolean }
```

### 3.7 生詞本

```
GET /api/vocab
  Header: Authorization: Bearer <token>
  Query: ?page=1&limit=20&sort=created_at
  Response: {
    vocab: VocabItem[],
    total: number,
    mastered_count: number
  }

DELETE /api/vocab/:id
  Header: Authorization: Bearer <token>
  Response: { success: boolean }
```

### 3.8 筆記（句子列表）

```
GET /api/sentences
  Header: Authorization: Bearer <token>
  Query: ?category=社畜日常&mastery=learning&page=1&limit=20
  Response: {
    sentences: Sentence[],
    total: number,
    mastered_count: number
  }

GET /api/sentences/stats
  Header: Authorization: Bearer <token>
  Response: {
    total_sentences: number,
    by_category: { [category: string]: number },
    by_mastery: { learning: number, mastered: number, needs_review: number }
  }
```

### 3.9 進度與統計

```
GET /api/progress/today
  Header: Authorization: Bearer <token>
  Response: {
    today: Progress,
    streak: StreakInfo,
    pet_mood: 'happy' | 'neutral' | 'quiet'
  }

GET /api/progress/history?days=30
  Header: Authorization: Bearer <token>
  Response: {
    history: Progress[],
    streak: StreakInfo
  }
```

### 3.10 精靈

```
GET /api/pet
  Header: Authorization: Bearer <token>
  Response: {
    pet: Pet,
    today_story: string           // 今日小故事文案
    decoration_stage: string
  }

GET /api/pet/memories
  Header: Authorization: Bearer <token>
  Response: {
    memories: PetMemory[]
  }

PATCH /api/pet/name
  Header: Authorization: Bearer <token>
  Body: { name: string }
  Response: { pet: Pet }
```

### 3.11 設定

```
GET /api/settings
  Header: Authorization: Bearer <token>
  Response: {
    voice_id: string,
    voice_gender: string,
    accent_preference: string,
    learning_language: string,
    notification_enabled: boolean,
    notification_time: string      // HH:mm
  }

PATCH /api/settings
  Header: Authorization: Bearer <token>
  Body: {
    voice_id?: string,
    voice_gender?: string,
    accent_preference?: string,
    notification_enabled?: boolean,
    notification_time?: string
  }
  Response: { settings: Settings }

GET /api/settings/voices
  Header: Authorization: Bearer <token>
  Response: {
    voices: VoiceOption[]
  }

interface VoiceOption {
  id: string;                      // 如 'nova'
  label: string;                   // 如 '美式女聲'
  gender: 'female' | 'male';
  accent: 'us' | 'uk';
  preview_audio_url: string;       // 試聽音頻 URL
  description: string;             // 如 '溫暖、自信、自然'
}
```

---

## 四、端點總覽

| 方法 | 路徑 | 用途 | 認證 |
|------|------|------|------|
| POST | /api/auth/register | 註冊 | ❌ |
| POST | /api/auth/login | 登入 | ❌ |
| POST | /api/auth/refresh | 刷新 Token | ✅ |
| GET | /api/onboarding/seed-sentences | 取得種子句 | ✅ |
| POST | /api/onboarding/complete | 完成 onboarding | ✅ |
| POST | /api/recording/upload | 上傳錄音 | ✅ |
| POST | /api/recording/confirm-transcript | 確認中文文字 | ✅ |
| POST | /api/recording/translate | AI 翻譯 + TTS | ✅ |
| POST | /api/recording/save | 存入筆記 + 選詞 | ✅ |
| GET | /api/listen/today | 取得今日聆聽列表 | ✅ |
| POST | /api/listen/complete | 完成一句聆聽 | ✅ |
| GET | /api/quiz/today | 取得今日 Quiz 卡 | ✅ |
| POST | /api/quiz/evaluate | Quiz 自評 | ✅ |
| GET | /api/preview/tomorrow | 取得明日預覽 | ✅ |
| POST | /api/preview/vocab/add | 預覽中加入生詞 | ✅ |
| POST | /api/preview/complete | 完成預覽 | ✅ |
| GET | /api/vocab | 取得生詞列表 | ✅ |
| DELETE | /api/vocab/:id | 刪除生詞 | ✅ |
| GET | /api/sentences | 取得句子列表 | ✅ |
| GET | /api/sentences/stats | 句子統計 | ✅ |
| GET | /api/progress/today | 今日進度 | ✅ |
| GET | /api/progress/history | 歷史進度 | ✅ |
| GET | /api/pet | 精靈狀態 | ✅ |
| GET | /api/pet/memories | 精靈回憶 | ✅ |
| PATCH | /api/pet/name | 改名 | ✅ |
| GET | /api/settings | 取得設定 | ✅ |
| PATCH | /api/settings | 更新設定 | ✅ |
| GET | /api/settings/voices | 聲線列表 | ✅ |

---

## 五、數據庫選型建議

| 方案 | 推薦場景 | 優勢 | 劣勢 |
|------|---------|------|------|
| **Supabase (PostgreSQL)** | MVP 首選 | 免費額度大、Auth 內建、Realtime、Row Level Security | 擴展性不如專用 DB |
| **Neon (PostgreSQL)** | 成長階段 | Serverless、自動擴展、分支（開發方便） | 免費額度較小 |
| **PlanetScale (MySQL)** | 大規模 | 無限擴展、零停機遷移 | 不支持 Foreign Key、較貴 |

**MVP 推薦：Supabase**
- Auth 免費（50K MAU）
- PostgreSQL 免費（500MB）
- Realtime 免費（2M 訊息/月）
- Storage 免費（1GB）— 存音頻可搭配 R2

**音頻存儲：Cloudflare R2**
- 免費 10GB + 免費出站流量
- 比 S3 便宜（無出站費用）
- 全球 CDN 內建
