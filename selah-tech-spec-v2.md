# Selah 技術規格書 v2.0

> 數據模型 + API 接口 + 語音方案 + 本地優先存儲 + 離線同步 + 錯誤處理

---

## 一、語音選擇方案

### 英語聲線（OpenAI TTS `tts-1`）

| 用戶選擇 | OpenAI Voice | 特徵描述 |
|---------|-------------|---------|
| 🇺🇸 美式女聲 | **nova** | 溫暖、自信、自然 |
| 🇺🇸 美式男聲 | **echo** | 清晰、友好、略帶活力 |
| 🇬🇧 英式女聲 | **shimmer** | 優雅、柔和、帶輕微英式腔調 |
| 🇬🇧 英式男聲 | **fable** | 沉穩、有質感、帶英式韻律感 |

### 日語聲線（Google Gemini TTS，未來擴展）

| 用戶選擇 | 聲線類型 | 特徵描述 |
|---------|---------|---------|
| 標準語女聲 A | 年輕女性・活潑 | 明亮、親切、語調自然 |
| 標準語女聲 B | 成熟女性・溫和 | 沉穩、溫柔、有知性美 |
| 標準語男聲 A | 年輕男性・清晰 | 清爽、有活力、發音清楚 |
| 標準語男聲 B | 成熟男性・沉穩 | 低沉、可靠、語速適中 |

---

## 二、本地優先存儲架構

### 核心原則

**音頻永遠不上傳到雲端。** 用戶的錄音和生成的 TTS 音頻全部存在設備本地。後端只做 AI 處理的「代理」，處理完立刻丟棄。

### 數據流

```
錄音流程：
  用戶錄音 → 本地暫存 → 上傳到後端 API（僅 STT 處理用）
    → 後端 Whisper STT → 返回文字 → 後端立刻刪除原始音頻
    → 後端 GPT-4o-mini 翻譯 → 返回英文 + 拆解數據
    → 後端調用 OpenAI TTS → 音頻 bytes 直傳客戶端 → 後端不存
  客戶端收到 Response → 音頻 bytes 存本地 → 文字存本地 SQLite → metadata 同步 Supabase

聆聽/播放：
  全部從本地讀取，不走網路
```

### 本地存儲結構

```
Selah/
├── Documents/
│   ├── audio/                    # 所有音頻文件
│   │   ├── sentences/            # TTS 生成的句子音頻
│   │   │   ├── {sentence_id}.mp3
│   │   │   └── ...
│   │   └── recordings/           # 用戶原始錄音（可選保留）
│   │       ├── {recording_id}.m4a
│   │       └── ...
│   └── selah.db                  # SQLite 數據庫（句子、生詞、進度等）
└── Library/
    └── Caches/
        └── audio_cache/          # 臨時音頻緩存（可被系統清除）
```

### 本地數據庫（SQLite / Core Data）

客戶端維護一份完整的本地數據庫副本，包含所有句子、生詞、進度數據。Supabase 只作為雲端備份，不作為主數據源。

```
本地表結構：
- sentences     (句子 + 拆解數據 + 本地音頻路徑)
- vocab_items   (生詞本)
- progress      (每日學習記錄)
- pet_state     (精靈狀態)
- pet_memories  (精靈回憶)
- settings      (用戶設定)
- sync_queue    (待同步到雲端的變更隊列)
```

### Sentence 模型（更新版）

```typescript
interface Sentence {
  id: string;                      // UUID（客戶端生成）
  
  // 原始中文
  zh_original: string;             // STT 辨識結果
  zh_corrected: string | null;     // 用戶修正後的中文
  
  // AI 生成的英文
  en_translation: string;
  
  // 音頻（本地存儲）
  local_audio_path: string;        // 本地文件路徑（如 "Documents/audio/sentences/{id}.mp3"）
  audio_duration_ms: number;
  voice_id: string;                // 生成時使用的聲線
  
  // 拆解數據
  deconstruction: Deconstruction;
  vocab_candidates: VocabCandidate[];
  
  // 分類
  category: SentenceCategory;
  
  // 來源
  source: 'user_recording' | 'system_seed';
  
  // 生命週期
  created_at: DateTime;
  preview_available_at: DateTime;
  listen_available_at: DateTime;
  quiz_available_at: DateTime;
  mastery_status: 'learning' | 'mastered' | 'needs_review';
  
  // 同步狀態
  synced_to_cloud: boolean;        // 是否已同步到 Supabase
  last_synced_at: DateTime | null;
}
```

---

## 三、離線同步邏輯

### 同步策略：Local-First + Eventual Consistency

```
寫入流程：
  1. 所有寫入先寫本地 SQLite
  2. 同時加入 sync_queue（記錄變更類型：insert/update/delete）
  3. 有網路時，背景執行 sync_queue → 推送到 Supabase
  4. 推送成功後從 sync_queue 移除

讀取流程：
  永遠從本地 SQLite 讀取，不直接查 Supabase
```

### sync_queue 結構

```typescript
interface SyncQueueItem {
  id: string;                      // UUID
  entity_type: 'sentence' | 'vocab' | 'progress' | 'pet' | 'settings';
  entity_id: string;               // 被變更的實體 ID
  operation: 'insert' | 'update' | 'delete';
  payload: JSON;                   // 變更的數據（或 null for delete）
  created_at: DateTime;
  retry_count: number;             // 重試次數
  last_error: string | null;
}
```

### 衝突解決

由於 Selah 是單用戶 App，衝突概率極低。策略：

| 場景 | 策略 |
|------|------|
| 同一句子在兩台設備修改 | **Last Write Wins**（以時間戳為準） |
| 生詞在一台加入、另一台刪除 | **Delete Wins**（刪除優先） |
| 進度數據衝突 | **Merge**（取兩邊的最大值） |
| 設定衝突 | **Last Write Wins** |

### 離線可用功能

| 功能 | 離線可用 | 說明 |
|------|---------|------|
| 聆聽（播放已下載的音頻） | ✅ | 音頻已在本地 |
| Quiz 翻卡 | ✅ | 數據已在本地 |
| 夜間預覽 | ✅ | 數據已在本地 |
| 瀏覽筆記 | ✅ | 本地 SQLite |
| 查看生詞本 | ✅ | 本地 SQLite |
| 寵物動畫 | ✅ | 純前端邏輯 |
| **錄音（新句子）** | ❌ | 需要後端 STT + AI 翻譯 + TTS |
| **切換聲線** | ❌ | 需要重新生成 TTS |
| **首次打開（冷啟動）** | ❌ | 需要下載種子句 |

---

## 四、錯誤處理規格

### 4.1 錄音流程錯誤

| 錯誤 | 觸發條件 | 用戶看到的 | 處理方式 |
|------|---------|-----------|---------|
| **無麥克風權限** | 用戶未授權 | Toast：「需要麥克風權限才能錄音。請到設定中開啟。」 | 引導到系統設定 |
| **無網路** | 錄音時離線 | Toast：「目前離線，錄音需要網路連線。」 | 禁用錄音按鈕，顯示離線狀態 |
| **STT 失敗** | Whisper API 錯誤 | Toast：「聽不清楚，可以再說一次嗎？」 | 保留錄音，允許重新提交 |
| **STT 結果為空** | 錄音太短或無語音 | Toast：「好像沒有聽到聲音，再試一次？」 | 清空文字框 |
| **AI 翻譯失敗** | GPT API 錯誤 | Toast：「精靈暫時想不到英文，稍後再試。」 | 保留中文，提供「重試」按鈕 |
| **TTS 失敗** | OpenAI TTS 錯誤 | Toast：「語音生成失敗，但句子已保存。可以稍後重新生成。」 | 保存句子但不含音頻，顯示「生成語音」按鈕 |
| **API 超時** | 請求超過 30 秒 | Toast：「網路有點慢，正在努力處理中⋯⋯」 | 顯示載入動畫，60 秒後超時提示 |
| **配額用盡** | 免費用戶超過每日錄音上限 | Toast：「今天的錄音次數已用完，明天再來吧！🌱」 | 禁用錄音按鈕，顯示剩餘時間 |

### 4.2 聆聽流程錯誤

| 錯誤 | 觸發條件 | 用戶看到的 | 處理方式 |
|------|---------|-----------|---------|
| **音頻文件丟失** | 本地音頻被系統清除 | 播放按鈕顯示「重新生成」圖標 | 點擊後調用 TTS API 重新生成 |
| **今日無句子** | 新用戶還沒錄音 | 空狀態：「還沒有句子可以聽。先說一句中文吧！🎙️」 | 引導到錄音頁面 |

### 4.3 Quiz 流程錯誤

| 錯誤 | 觸發條件 | 用戶看到的 | 處理方式 |
|------|---------|-----------|---------|
| **無可複習的句子** | 還沒完成任何聆聽 | 空狀態：「先完成聆聽，句子才會出現在這裡喔！」 | 引導到聆聽頁面 |

### 4.4 全域錯誤

| 錯誤 | 觸發條件 | 用戶看到的 | 處理方式 |
|------|---------|-----------|---------|
| **網路斷線** | 任何需要網路的操作 | 頂部 Banner：「目前離線 — 部分功能不可用」 | 顯示離線 Banner，禁用需網路的操作 |
| **同步失敗** | sync_queue 推送失敗 | 不顯示（背景靜默重試） | 指數退避重試（1s → 2s → 4s → 8s → 最大 60s） |
| **Token 過期** | API 返回 401 | 不顯示（背景靜默刷新） | 自動 refresh token，重試原請求 |
| **App 版本過舊** | 伺服器返回 upgrade_required | Modal：「請更新到最新版本以繼續使用。」 | 引導到 App Store |

---

## 五、數據模型

### 5.1 User

```typescript
interface User {
  id: string;
  email: string;
  display_name: string;
  created_at: DateTime;
  last_active_at: DateTime;
  total_days: number;
  onboarding_completed: boolean;
  learning_language: 'en' | 'ja';
  accent_preference: 'us' | 'uk';
  voice_id: string;
  voice_gender: 'female' | 'male';
  subscription_tier: 'free' | 'pro';
  daily_recordings_used: number;
  daily_recording_limit: number;  // free=1, pro=∞
}
```

### 5.2 Pet

```typescript
interface Pet {
  user_id: string;
  name: string;
  created_at: DateTime;
  decoration_stage: 'none' | 'sprout' | 'leaf' | 'bud' | 'bloom';
  current_mood: 'happy' | 'neutral' | 'quiet';
  last_interaction_at: DateTime;
}
```

### 5.3 Sentence（本地優先）

```typescript
interface Sentence {
  id: string;
  zh_original: string;
  zh_corrected: string | null;
  en_translation: string;
  local_audio_path: string;        // 本地路徑
  audio_duration_ms: number;
  voice_id: string;
  deconstruction: Deconstruction;
  vocab_candidates: VocabCandidate[];
  category: SentenceCategory;
  source: 'user_recording' | 'system_seed';
  created_at: DateTime;
  preview_available_at: DateTime;
  listen_available_at: DateTime;
  quiz_available_at: DateTime;
  mastery_status: 'learning' | 'mastered' | 'needs_review';
  synced_to_cloud: boolean;
  last_synced_at: DateTime | null;
}
```

### 5.4 VocabItem

```typescript
interface VocabItem {
  id: string;
  word: string;
  meaning: string;
  source_sentence_id: string;
  source_sentence_zh: string;
  encountered_count: number;
  used_in_recording: boolean;
  used_count: number;
  mastery: 'new' | 'familiar' | 'mastered';
  created_at: DateTime;
  last_encountered_at: DateTime;
  synced_to_cloud: boolean;
}
```

### 5.5 Progress

```typescript
interface Progress {
  user_id: string;
  date: string;                  // YYYY-MM-DD
  sentences_listened: number;
  quiz_cards_reviewed: number;
  quiz_good_count: number;
  quiz_mid_count: number;
  quiz_fail_count: number;
  recordings_made: number;
  vocab_added: number;
  is_active_day: boolean;
  synced_to_cloud: boolean;
}
```

### 5.6 SeedSentence

```typescript
interface SeedSentence {
  id: string;
  zh_text: string;
  en_translation: string;
  audio_url: string;             // 種子句音頻存在 CDN（預生成）
  deconstruction: Deconstruction;
  vocab_candidates: VocabCandidate[];
  category: SentenceCategory;
  difficulty: 'basic' | 'intermediate';
  seed_tags: string[];
}
```

### 5.7 PetMemory

```typescript
interface PetMemory {
  id: string;
  day_number: number;
  memory_type: MemoryType;
  title: string;
  description: string;
  icon: string;
  created_at: DateTime;
  synced_to_cloud: boolean;
}

type MemoryType = 
  | 'time_milestone' | 'content_milestone' | 'first_experience'
  | 'special_moment' | 'vocab_journey' | 'growth_observation';
```

---

## 六、API 接口規格

### 錄音流程（核心，4 步合一）

```
POST /api/recording/process
  Header: Authorization: Bearer <token>
  Content-Type: multipart/form-data
  Body: {
    audio: File,                    // 錄音文件（M4A/AAC）
    category: SentenceCategory | null,
    voice_id: string
  }
  Response (200): {
    zh_text: string,                // STT 結果
    en_text: string,                // AI 翻譯
    deconstruction: Deconstruction,
    vocab_candidates: VocabCandidate[],
    audio_data: string,             // Base64 編碼的 MP3 bytes
    audio_format: 'mp3',
    audio_duration_ms: number
  }
  
  Response (400): { error: 'stt_failed' | 'too_short' | 'empty' }
  Response (500): { error: 'translation_failed' | 'tts_failed' }
  Response (429): { error: 'quota_exceeded', reset_at: string }
  
  後端處理流程：
  1. 接收音頻 → Whisper STT → 得到中文
  2. GPT-4o-mini 翻譯 → 得到英文 + 拆解 + 詞彙
  3. OpenAI TTS → 得到音頻 bytes
  4. 刪除所有臨時文件
  5. 返回 JSON（含 Base64 音頻）
```

### 其餘 API（簡化版）

```
# 認證
POST /api/auth/register    Body: { email, password, display_name }
POST /api/auth/login       Body: { email, password }
POST /api/auth/refresh     Header: Bearer <token>

# Onboarding
GET  /api/onboarding/seeds?language=en
POST /api/onboarding/complete
  Body: { pet_name, language, accent, voice_id, gender, seed_ids[] }

# 聆聽
GET  /api/listen/today
POST /api/listen/complete   Body: { sentence_id, listen_count, predict_correct, shadow_done }

# Quiz
GET  /api/quiz/today
POST /api/quiz/evaluate     Body: { card_id, card_type, result }

# 預覽
GET  /api/preview/tomorrow
POST /api/preview/complete

# 生詞
GET  /api/vocab?page=1&limit=20
DELETE /api/vocab/:id

# 句子
GET  /api/sentences?category=&mastery=&page=1
GET  /api/sentences/stats

# 進度
GET  /api/progress/today
GET  /api/progress/history?days=30

# 精靈
GET  /api/pet
GET  /api/pet/memories
PATCH /api/pet/name         Body: { name }

# 設定
GET  /api/settings
PATCH /api/settings          Body: { voice_id?, accent?, notification_enabled?, notification_time? }
GET  /api/voices

# 同步
POST /api/sync/push          Body: { changes: SyncQueueItem[] }
GET  /api/sync/pull?since=DateTime
```

---

## 七、技術棧總覽

| 層級 | 方案 | 說明 |
|------|------|------|
| 前端 | SwiftUI (iOS 17+) | 原生 iOS App |
| 本地數據庫 | SQLite (via GRDB) | 本地優先，完整數據副本 |
| 本地音頻存儲 | FileManager | Documents/audio/ 目錄 |
| 後端 | Supabase Edge Functions | 純 API 代理，不存文件 |
| 雲端數據庫 | Supabase PostgreSQL | 用戶數據備份 + 跨設備同步 |
| 認證 | Supabase Auth | 免費 50K MAU |
| STT | OpenAI Whisper API | 用完即棄，不存音頻 |
| AI 翻譯 | GPT-4o-mini API | ~$0.0001/次 |
| TTS（英語） | OpenAI TTS (tts-1) | 音頻直傳客戶端，不存 |
| TTS（日語，未來） | Google Gemini TTS | 日語品質最佳 |
| 種子句音頻 CDN | Cloudflare R2 | 僅存預生成的種子句音頻（~20 個文件） |
| 同步 | Local-first + sync_queue | 背景靜默同步 |

---

## 八、端點總覽（26 個）

| 方法 | 路徑 | 用途 |
|------|------|------|
| POST | /api/auth/register | 註冊 |
| POST | /api/auth/login | 登入 |
| POST | /api/auth/refresh | 刷新 Token |
| GET | /api/onboarding/seeds | 種子句列表 |
| POST | /api/onboarding/complete | 完成 onboarding |
| **POST** | **/api/recording/process** | **錄音處理（核心）** |
| GET | /api/listen/today | 今日聆聽列表 |
| POST | /api/listen/complete | 完成聆聽 |
| GET | /api/quiz/today | 今日 Quiz |
| POST | /api/quiz/evaluate | Quiz 自評 |
| GET | /api/preview/tomorrow | 明日預覽 |
| POST | /api/preview/complete | 完成預覽 |
| GET | /api/vocab | 生詞列表 |
| DELETE | /api/vocab/:id | 刪除生詞 |
| GET | /api/sentences | 句子列表 |
| GET | /api/sentences/stats | 句子統計 |
| GET | /api/progress/today | 今日進度 |
| GET | /api/progress/history | 歷史進度 |
| GET | /api/pet | 精靈狀態 |
| GET | /api/pet/memories | 精靈回憶 |
| PATCH | /api/pet/name | 改名 |
| GET | /api/settings | 設定 |
| PATCH | /api/settings | 更新設定 |
| GET | /api/voices | 聲線列表 |
| POST | /api/sync/push | 推送本地變更 |
| GET | /api/sync/pull | 拉取雲端變更 |
