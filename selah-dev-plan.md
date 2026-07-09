# Selah MVP — 完整開發執行計劃

> 本文檔是 Selah iOS App MVP 的唯一執行參照。所有開發任務、依賴關係、前置準備均在此定義。
> 最後更新：2026-07-07

---

## 前置準備（用戶需在開發啟動前完成）

以下事項必須由用戶本人完成，AI 代理無法代辦：

### P1. 帳號與服務

| 項目 | 具體操作 | 完成標記 |
|------|---------|---------|
| Apple Developer 帳號 | 註冊/確認 Apple Developer Program 會員（$99/年） | 能登入 developer.apple.com |
| Supabase 專案 | 在 supabase.com 建立新專案，記下 Project URL + anon key + service_role key | 有 Project URL 和 Keys |
| OpenAI API Key | 在 platform.openai.com 建立 API Key，確保有 GPT-5.4 Mini + TTS (tts-1) + Whisper 的權限 | API Key 可用 |
| Cloudflare 帳號 | 註冊 Cloudflare（免費），建立 R2 Bucket 用於種子句音頻存儲 | 有 R2 Bucket URL |
| PostHog 帳號 | 註冊 PostHog（免費開源）或 TelemetryDeck，取得 Project API Key | 有 API Key |

### P2. 開發環境

| 項目 | 具體要求 |
|------|---------|
| Mac 電腦 | macOS 14+ (Sonoma 或更新) |
| Xcode | 15.4+ (支援 iOS 17 SDK) |
| iOS 設備 | 至少一台 iPhone（用於真機測試，模擬器無法測試麥克風和 Speech 框架） |
| Node.js | 18+（用於 Supabase Edge Functions 本地開發） |
| Supabase CLI | `brew install supabase/tap/supabase`（本地開發用） |

### P3. 設計資產

| 項目 | 狀態 | 說明 |
|------|------|------|
| 互動原型 | ✅ 已完成 | `selah-prototype-v7.html` — 所有畫面的互動邏輯參照 |
| 設計規格 | ✅ 已完成 | `selah-ios-design-spec.md` — Design Tokens + 組件庫 + 畫面規格 |
| 寵物概念圖 | ✅ 已完成 | `pet-concept-C.png` — 選定的種子精靈設計方向 |
| 動畫規格 | ✅ 已完成 | `selah-seed-animations-v2.md` — 120 種姿態的完整定義 |
| 動畫樣片 | ✅ 已完成 | `seed-animations/` — 3 個 HyperFrames 渲染的 MP4 參考 |
| 寵物 Lottie/Rive 動畫 | ❌ 待製作 | 需要確定動畫方案（SwiftUI 原生 / Lottie / Rive）後製作 |
| App Icon | ❌ 待設計 | 需要設計 1024x1024 的 App Icon |
| App Store 截圖 | ❌ 待製作 | 6.7 寸 + 5.5 寸各 5 張，開發後期截圖 |

### P4. 環境變數

開發啟動前，需要在專案的 `.env` 中填入以下值：

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# OpenAI
OPENAI_API_KEY=sk-your-openai-api-key

# Cloudflare R2
R2_BUCKET_NAME=selah-seed-audio
R2_ACCOUNT_ID=your-cf-account-id
R2_ACCESS_KEY_ID=your-r2-access-key
R2_SECRET_ACCESS_KEY=your-r2-secret-key
R2_PUBLIC_URL=https://your-r2-bucket.r2.dev

# Analytics
POSTHOG_API_KEY=your-posthog-key

# App Config
DEFAULT_DAILY_RECORDING_LIMIT=1
```

---

## 參考文檔索引

所有開發任務必須參照以下文檔：

| 文檔 | 路徑 | 用途 |
|------|------|------|
| 產品設計文檔 | `selah-design-v7.md` | 產品哲學、功能定義、流程設計 |
| 技術規格書 | `selah-tech-spec-v2.md` | 數據模型、API 接口、存儲架構、錯誤處理 |
| iOS 設計規格 | `selah-ios-design-spec.md` | Design Tokens、組件庫、畫面 Layout、Haptic |
| 用戶故事 | `selah-user-stories.md` | 18 個 User Story + Acceptance Criteria |
| 動畫規格 | `selah-seed-animations-v2.md` | 120 種寵物姿態的觸發條件和動作描述 |
| 互動原型 | `selah-prototype-v7.html` | 可直接在瀏覽器測試的互動原型 |
| 架構報告 | `selah-architecture.html` | 前後端分工、成本分析、服務商比較 |

---

## 工作流 A：Supabase 後端

### A1. Supabase 專案建立與配置

**預估**：0.5 天
**前置條件**：用戶已完成 P1 中的 Supabase 專案建立

```
任務：
1. 在 Supabase Dashboard 建立新專案
2. 設定 Project Settings → API → 確認 REST API 可用
3. 設定 Project Settings → Database → 啟用 Row Level Security
4. 建立 .env 文件，填入 SUPABASE_URL 和 Keys
5. 安裝 Supabase CLI，執行 `supabase link` 連結專案
```

**驗收標準**：
- `supabase status` 顯示正常
- `.env` 包含所有必要環境變數
- Supabase Dashboard 可正常存取

---

### A2. 數據庫 Schema + Migration

**預估**：1 天
**前置條件**：A1 完成
**參照文檔**：`selah-tech-spec-v2.md` 第二節「數據模型」

```
任務：
1. 建立 migration 文件（supabase/migrations/001_initial_schema.sql）
2. 建立以下表（含索引和約束）：
   - users (extends Supabase auth.users)
   - pets
   - sentences
   - vocab_items
   - progress
   - pet_memories
   - seed_sentences
   - sync_queue
3. 所有表添加 updated_at 自動更新 trigger
4. 所有 user_id 欄位添加 foreign key → auth.users(id)
5. 執行 migration：`supabase db push`
```

**驗收標準**：
- 所有表在 Supabase Dashboard Table Editor 中可見
- 表結構與 `selah-tech-spec-v2.md` 定義一致
- RLS 已啟用（但未設定 policy，在 A3 設定）

---

### A3. Row Level Security

**預估**：0.5 天
**前置條件**：A2 完成

```
任務：
1. 為所有表建立 RLS policy：
   - 用戶只能 INSERT/SELECT/UPDATE/DELETE 自己的數據
   - seed_sentences 表對所有已認證用戶可讀
2. 使用 auth.uid() 函數在 policy 中判斷用戶身份
3. 測試：用兩個不同用戶登入，確認無法存取對方數據
```

**驗收標準**：
- 用戶 A 無法 SELECT 用戶 B 的 sentences
- 所有認證用戶可 SELECT seed_sentences
- 未認證用戶無法存取任何表

---

### A4. Auth 設定

**預估**：0.5 天
**前置條件**：A1 完成

```
任務：
1. Supabase Dashboard → Authentication → Providers → 啟用 Email
2. 關閉「Confirm email」（MVP 階段不需要郵件驗證）
3. 設定 Auth Hooks：
   - on_auth_user_created → 自動在 users 表創建記錄
   - on_auth_user_created → 自動在 pets 表創建記錄
4. 設定 Token 有效期：access_token 1 小時，refresh_token 30 天
```

**驗收標準**：
- 透過 Supabase JS SDK 可成功註冊、登入、刷新 token
- 註冊後 users 表和 pets 表自動有對應記錄

---

### A5. Edge Function：recording/process（核心）

**預估**：2 天
**前置條件**：A4 完成
**參照文檔**：`selah-tech-spec-v2.md` 第六節「API 接口規格」

```
任務：
1. 建立 Edge Function：supabase/functions/recording-process/index.ts
2. 接收 JSON body：{ zh_text: string, voice_id: string, category?: string }
3. 調用 OpenAI API（GPT-5.4 Mini）進行翻譯：
   - System prompt 需包含：教學導向翻譯規則 + 發音偏好（美/英式）+ 拆解格式要求
   - 輸出結構：{ en_text, deconstruction: { chunks[] }, vocab_candidates[] }
4. 調用 OpenAI TTS API（tts-1）：
   - 使用 voice_id 參數
   - speed 預設 0.85
   - 返回 mp3 bytes
5. 將 en_text + deconstruction + vocab_candidates + audio_data(base64) + audio_duration_ms 打包返回
6. 錯誤處理：
   - GPT API 失敗 → 返回 500 { error: 'translation_failed' }
   - TTS API 失敗 → 返回 500 { error: 'tts_failed' }
   - 請求超時 → 60 秒 timeout
```

**驗收標準**：
- POST 中文文字 → 返回英文翻譯 + 拆解數據 + Base64 音頻
- 音頻可正常解碼播放
- 切換 voice_id 可得到不同聲線的音頻
- 切換 accent_preference 可得到不同風格的翻譯用詞

---

### A6. Edge Function：sync/push + sync/pull

**預估**：1 天
**前置條件**：A2, A3 完成

```
任務：
1. sync/push：接收客戶端 sync_queue 變更 → 批量寫入對應表
   - INSERT：插入新記錄
   - UPDATE：更新現有記錄（以 entity_id 匹配）
   - DELETE：刪除記錄
   - 衝突策略：Last Write Wins（以 updated_at 為準）
2. sync/pull：接收 since（DateTime）→ 返回該時間後的所有變更
   - 查詢所有表的 updated_at > since 的記錄
   - 返回 { changes: [{ entity_type, entity_id, operation, payload }] }
3. 認證：兩個函數都需要 Bearer token 驗證
```

**驗收標準**：
- 客戶端 push 一筆 sentence INSERT → 數據庫有記錄
- 客戶端 pull since=T → 返回 T 之後的所有變更
- 衝突時以最新 updated_at 為準

---

### A7. 種子句數據準備

**預估**：1 天
**前置條件**：A2 完成

```
任務：
1. 準備 18-20 句種子句（每句包含）：
   - zh_text：自然中文口語
   - en_translation：道地英文（GPT-5.4 Mini 預生成）
   - deconstruction：拆解數據（詞組 chunks + 解釋）
   - vocab_candidates：2-3 個可教學詞組
   - category：6 分類各 3 句
   - difficulty：basic 或 intermediate
   - seed_tags：主題標籤（用於 onboarding 選擇）
2. 寫入 seed_sentences 表
3. 確保涵蓋所有 6 個分類，每分類至少 3 句
```

**驗收標準**：
- seed_sentences 表有 18-20 筆記錄
- 6 個分類各有至少 3 句
- 每句的 deconstruction 和 vocab_candidates 結構完整

---

### A8. 種子句音頻預生成 + CDN

**預估**：0.5 天
**前置條件**：A5, A7 完成

```
任務：
1. 對每句種子句調用 OpenAI TTS，使用 4 種聲線各生成一份：
   - nova (美式女), echo (美式男), shimmer (英式女), fable (英式男)
   - 共 18 句 × 4 聲線 = 72 個音頻文件
2. 上傳到 Cloudflare R2：
   - 路徑格式：seeds/{sentence_id}/{voice_id}.mp3
3. 設定 R2 為 public read
4. 更新 seed_sentences 表的 audio_url 欄位
```

**驗收標準**：
- R2 上有 72 個 mp3 文件
- 每個 URL 可公開存取並播放
- seed_sentences.audio_url 指向正確的 CDN URL

---

### A9. 翻譯 Prompt 工程

**預估**：2-3 天
**前置條件**：A5 基本完成（可並行調優）

```
任務：
1. 設計 System Prompt，包含：
   - 角色定義：你是教學導向翻譯引擎
   - 翻譯規則：自然口語、非教科書、微微超前用戶水平（i+1）
   - 發音偏好：根據 accent 參數調整用詞風格
   - 輸出格式：JSON（en_text + deconstruction + vocab_candidates）
   - 拆解規則：標記 phrase/pattern/word 三種類型
   - 詞彙規則：只標記「可教學」的詞組，跳過基礎詞
2. 用 10 句不同類型的中文測試，人工審查翻譯品質
3. 反覆調優 prompt 直到翻譯品質穩定
4. 最終 prompt 存入 Edge Function 的 constants 中
```

**驗收標準**：
- 翻譯結果自然口語化（非逐字翻譯）
- 拆解的 chunks 確實標出核心詞組和句型
- vocab_candidates 不包含 too basic 的詞（如 I, you, the）
- 美式/英式偏好能體現在用詞差異上

---

## 工作流 B：iOS App（SwiftUI）

### B1. 專案初始化

**預估**：2 天
**前置條件**：用戶完成 P2（Xcode + iOS 設備）

```
任務：
1. Xcode → New Project → iOS App → SwiftUI → iOS 17.0+
2. 專案名稱：Selah，Bundle ID：com.yourname.selah
3. 加入 Swift Package Dependencies：
   - supabase-swift（Supabase SDK）
   - grdb.swift（SQLite ORM）
   - kingfisher（圖片快取，可選）
4. 建立專案結構：
   Selah/
   ├── App/              # App 入口、環境變數
   ├── Features/         # 功能模組（Onboarding/Today/Listen/Quiz/Record/Notes/Settings）
   ├── Core/             # 核心服務（Database/Sync/Audio/Analytics）
   ├── Models/           # 數據模型（對應 selah-tech-spec-v2.md）
   ├── Components/       # 可複用 UI 組件（對應 selah-ios-design-spec.md）
   ├── Resources/        # 資源文件（字體、顏色、音頻）
   └── Utils/            # 工具函數
5. 設定 Design Tokens（Color/Font/Spacing extensions）
   參照：selah-ios-design-spec.md 第一節
6. 設定 Supabase 客戶端初始化
7. 設定本地 SQLite 數據庫（GRDB）初始化 + Migration
8. 設定 CI/CD：Xcode Cloud 或 GitHub Actions → TestFlight
```

**驗收標準**：
- 專案可在模擬器和真機上編譯運行
- Supabase 客戶端可成功連線
- 本地 SQLite 可讀寫
- Design Tokens 所有顏色/字體/間距可用

---

### B2. 註冊/登入

**預估**：1 天
**前置條件**：B1, A4 完成
**參照 User Story**：US-002

```
任務：
1. 建立 AuthView（註冊/登入共用畫面）
2. Email + Password 輸入 + 驗證（密碼 ≥8 位）
3. 調用 Supabase Auth signUp / signIn
4. Token 存入 Keychain（非 UserDefaults）
5. 自動登入邏輯：App 啟動時檢查 Keychain → refresh token → 進入對應頁面
6. 錯誤處理：密碼錯誤、email 已存在、網路錯誤
```

**驗收標準**：
- 可成功註冊並自動登入
- 關閉 App 重新打開可自動登入
- 錯誤訊息符合 selah-tech-spec-v2.md 第四節定義

---

### B3. Onboarding 全流程

**預估**：3-4 天
**前置條件**：B2, A7, A8 完成
**參照 User Story**：US-003

```
任務：
1. 6 步 Onboarding 頁面（NavigationStack）：
   Step 1: 語言選擇（English / 日本語・稍後）
   Step 2: 發音偏好（🇺🇸 美式 / 🇬🇧 英式）
   Step 3: 聲線性別（♀ / ♂）+ 試聽按鈕（從 R2 載入種子句試聽音頻）
   Step 4: 寵物命名（文字輸入 + 精靈蛋動畫）
   Step 5: 種子句選擇（6 選 3，含分類標籤）
   Step 6: 孵化動畫（全屏 overlay → 轉場）
2. 狀態持久化：中途關閉 App 後回到上次步驟
3. 完成後：
   - 下載 3 句種子句音頻到本地
   - 初始化本地 SQLite 數據
   - 同步到 Supabase
   - 進入今日頁面
```

**驗收標準**：
- 6 步流暢過渡，無卡頓
- 中途殺進程後重開可恢復
- 完成後本地有 3 句種子句（含音頻）
- 孵化動畫流暢

---

### B4. 錄音頁面與話題引導

**預估**：2 天
**前置條件**：B3 完成
**參照 User Story**：US-004

```
任務：
1. RecordView 頁面結構（Push navigation）：
   - 6 個話題 chips（水平滾動）
   - 選擇話題後顯示 4 個 starter 句（點擊填入）
   - 麥克風按鈕（大圓形，按住錄音/點擊切換）
   - iOS Speech Framework 即時辨識（SFSpeechRecognizer）
   - 辨識文字即時顯示在 textarea 中
   - 錄音結束後用戶可修正文字
2. 免費用戶每日錄音次數限制檢查
3. 麥克風權限請求（首次使用時）
```

**驗收標準**：
- 話題 chips 可選/取消
- 點擊 starter 句可填入 textarea
- 麥克風錄音時波形動畫正常
- Speech 即時辨識可顯示中文文字
- 免費用戶超限時按鈕禁用 + 提示

---

### B5. 錄音核心流程

**預估**：3 天
**前置條件**：B4, A5 完成
**參照 User Story**：US-005

```
任務：
1. 錄音結束 → 取得 SFSpeechRecognizer 辨識結果
2. 用戶確認/修正中文文字 → 點擊「產生英文」
3. 調用 Edge Function /api/recording/process
   - Body: { zh_text, voice_id, category }
   - 顯示載入動畫（精靈思考中⋯⋯）
4. 接收 Response：
   - 解析 JSON
   - Base64 音頻解碼 → 存入本地 FileManager (Documents/audio/sentences/{id}.mp3)
   - 句子數據存入本地 SQLite
   - 加入 sync_queue 待同步
5. 錯誤處理：
   - 網路斷線 → Toast + 禁用按鈕
   - STT 失敗（不會發生，因為用 iOS 原生）
   - 翻譯失敗 → Toast「精靈暫時想不到英文」+ 重試按鈕
   - TTS 失敗 → 句子保存但不含音頻 + 「生成語音」按鈕
```

**驗收標準**：
- 錄音 → 翻譯 → 音頻播放全链路通
- 音頻文件正確存在本地
- 句子數據正確存入 SQLite
- 所有錯誤場景有對應 Toast 提示

---

### B6. 詞彙選擇與存檔

**預估**：1 天
**前置條件**：B5 完成
**參照 User Story**：US-006

```
任務：
1. 錄音結果頁面顯示 AI 翻譯 + 詞彙候選 chips
2. Chips 可勾選/取消（toggleRecVocab 邏輯）
3. 點擊英文句子中的詞 → VocabPopup 浮層
4. 「存入筆記」按鈕 → 句子存本地 + 勾選的詞加入生詞本 + Toast
5. 存入後返回今日頁面
```

**驗收標準**：
- Chips 可正常勾選/取消
- VocabPopup 定位正確
- 存入後句子出現在筆記頁面
- Toast 顯示正確的詞彙數量

---

### B7-B9. 聆聽系統

**預估**：5 天（B7: 1d, B8: 2d, B9: 2d）
**前置條件**：B5 完成（有句子和音頻）
**參照 User Story**：US-007, US-008, US-009

```
B7 — 聆聽頁面骨架（1 天）：
1. ListenView 頁面結構（Push navigation）
2. Playlist 計數器（第 N/M 句 + ◀ ▶ 切換）
3. StageBar 組件（4 步驟指示器 + 進度條）
4. 速度切換按鈕（0.85x → 1.0x → 1.2x → 0.7x 循環）
5. AVAudioPlayer 初始化 + 播放控制

B8 — 盲聽 + 預測（2 天）：
1. Step 1：音頻播放 + 計數（3 遍）+ 隱藏中英文文字
2. Step 2 解鎖邏輯：3 遍完成後解鎖
3. Step 2：預測按鈕 + 3 秒最低思考時間
   - predictStartTime 正確重置（跨句子）
   - predictTimer 正確清除（離開頁面時）
4. 揭示答案：中英文淡入 + predict result 顯示
5. Coach hint 系統（首次顯示 + dismiss）

B9 — 拆解 + 跟讀（2 天）：
1. Step 3：DeconstructBlock 組件
   - 詞組 chips（phrase/pattern 兩種樣式）
   - 點擊 chip → VocabPopup
   - 「理解了，繼續跟讀」按鈕
2. Step 4：ShadowCard 組件
   - 英文句子顯示（Step 3 完成後才顯示）
   - 麥克風錄音（AVAudioRecorder）
   - 原生音頻播放比對
   - 「完成本句」按鈕 → 下一句或完成
3. 完成所有句子 → Toast + 返回今日頁面
```

**驗收標準**：
- 4 步流程全部可用
- 速度切換正常
- 3 秒預測限制正確
- Stage 3/4 內容在解鎖前完全隱藏
- Coach hints 首次顯示後不再出現

---

### B10. Quiz 翻卡練習

**預估**：2-3 天
**前置條件**：B9 完成（有完成聆聽的句子）
**參照 User Story**：US-010

```
任務：
1. QuizView 頁面（Push navigation）
2. 翻卡動畫（中文 → 點擊揭示 → 英文淡入）
3. 三點自評按鈕（good/mid/fail）
4. 進度條 + 計數器
5. 間隔重複選題邏輯：
   - 從 mastery_status='learning' 的句子中選取
   - 優先選上次 result='fail' 的句子
   - 每輪 3 張卡
6. 完成畫面（🎉 + 引導錄音）
7. 空狀態（無可複習句子）
8. 自評結果寫入本地 Progress
```

**驗收標準**：
- 翻卡動畫流暢
- 三點自評後切換到下一張
- 完成後進度更新
- 空狀態正確顯示

---

### B11. 夜間預覽

**預估**：1-2 天
**前置條件**：B5 完成
**參照 User Story**：US-011

```
任務：
1. PreviewView 頁面（Push navigation）
2. 時段控制：21:00 前不可進入
3. 句子列表：明日新句（2-3 句）+ 舊句複習（1-2 句）
4. PreviewCard 組件（序號 + 播放按鈕 + 中英文 + 高亮詞組）
5. 點擊高亮詞組 → VocabPopup
6. 「預習好了」按鈕 → Toast + 返回
```

**驗收標準**：
- 21:00 前按鈕禁用 + 提示文字
- 句子列表正確顯示
- VocabPopup 正常工作

---

### B12. 筆記頁面

**預估**：2 天
**前置條件**：B5 完成
**參照 User Story**：US-012, US-013

```
任務：
1. NotesView 頁面（Tab 2）
2. 句子列表（LazyVStack + 分類篩選 chips）
3. 統計標題（N 句 · 掌握 M 句）
4. 分類篩選邏輯（點擊 chip → 篩選 → 再點擊取消）
5. 生詞本區域：
   - 說明文字（跨分類共用邏輯）
   - VocabItem 列表（英文 + 中文 + 來源 + 掌握狀態）
   - 長按刪除
6. 小豆的回憶時間軸（PetMemory 列表）
7. 空狀態處理
```

**驗收標準**：
- 分類篩選正常
- 生詞本顯示正確
- 回憶時間軸顯示正確
- 空狀態有引導文案

---

### B13. 寵物系統

**預估**：2-3 天
**前置條件**：B3 完成（寵物已命名）
**參照 User Story**：US-014

```
任務：
1. PetView 組件（精靈 + 名字 + 心情 + 今日小故事）
2. 精靈 SVG/Shape 渲染（圓形身體 + 眼睛 + 嘴巴 + 腮紅 + 手臂）
3. 漸進裝飾邏輯：
   - Day 計算 = (today - pet.created_at).days
   - Day 1-3: 無裝飾
   - Day 4: +葉芽（Shape 或 Image）
   - Day 7: +大葉子
   - Day 10: +花苞
   - Day 14: +花朵
4. 心情計算：
   - 最近 3 天有活躍 → happy
   - 最近 1-2 天活躍 → neutral
   - 3+ 天未活躍 → quiet
5. 今日小故事：從預定義的 100 種文案中隨機選取
6. 回歸動畫（缺席 1+ 天後打開 App）
```

**驗收標準**：
- 精靈外觀符合 pet-concept-C.png
- 裝飾隨 Day 數漸進出現
- 心情正確反映活躍度
- 小故事每次打開可能不同

---

### B14. 寵物動畫

**預估**：2 天
**前置條件**：B13 完成
**參照 User Story**：US-015
**參照文檔**：`selah-seed-animations-v2.md`

```
任務：
1. 實現 P0 動畫（54 種中的核心子集）：
   - idle: gentle-float, blink, leaf-sway
   - action: listen-playing, quiz-good, quiz-fail, rec-done, listen-complete
   - emotion: happy-daily, welcome-back, encouragement
2. 動畫觸發系統：
   - AnimationManager 根據事件類型選擇動畫
   - idle 動畫在無操作 3-8 秒後隨機觸發
3. 確定動畫方案：
   方案 A: SwiftUI 原生動畫（.animation + withAnimation + phase animator）
   方案 B: Lottie（lottie-ios SDK + After Effects 製作 JSON）
   方案 C: Rive（rive SDK + Rive editor 製作 .riv 文件）
   → 建議 MVP 用方案 A，複雜動畫用方案 B 補充
```

**驗收標準**：
- gentle-float 在 idle 時自動播放
- quiz-good/quiz-fail 在對應操作時觸發
- 動畫流暢（60fps）
- 深夜時段動畫幅度減半

---

### B15. 智能推薦 + 學習教練

**預估**：1-2 天
**前置條件**：B3, B7, B10, B11 完成
**參照 User Story**：US-016, US-018

```
任務：
1. 智能推薦邏輯（updateGreeting 函數）：
   - 6-12 點：推薦聆聽 → 隱藏聆聽列
   - 12-18 點：推薦練習 → 隱藏練習列
   - 18-21 點：推薦聆聽 → 隱藏聆聽列
   - 21+ 點：推薦夜間預覽 → 不隱藏任何列
2. Coach Hint 系統：
   - CoachHintView 組件（含 dismiss 按鈕）
   - 每個 hint 的 dismiss 狀態存入 UserDefaults
   - 前 5 次進入頁面顯示，之後不再顯示
   - 7 個 coach hints：聆聽/預測/拆解/跟讀/Quiz/錄音
```

**驗收標準**：
- 不同時段推薦不同活動
- 推薦的活動列在下方隱藏
- Coach hints 首次顯示、dismiss 後不再出現

---

### B16. 設定頁面

**預估**：1 天
**前置條件**：B2 完成
**參照 User Story**：US-017

```
任務：
1. SettingsView 頁面（Push navigation）
2. 聲線選擇列表（4 個選項 + 試聽按鈕）
3. 通知開關 + 時間選擇器
4. 帳號資訊 + 登出按鈕
5. 本地通知排程（UNUserNotificationCenter）
```

**驗收標準**：
- 聲線切換後下次 TTS 使用新聲線
- 通知在指定時間觸發
- 登出後回到登入頁

---

### B17. 離線同步系統

**預估**：1-2 天
**前置條件**：B1 完成（Supabase SDK + 本地 SQLite）

```
任務：
1. SyncQueueManager：
   - 每次本地寫入同時加入 sync_queue
   - 背景定期執行 push（有網路時）
   - push 成功後從 queue 移除
2. Pull 邏輯：
   - App 啟動時 + 從背景恢復時執行 pull
   - 以 last_synced_at 為 since 參數
   - 接收到的變更寫入本地 SQLite
3. 衝突解決：Last Write Wins（updated_at 為準）
4. 離線狀態 Banner：頂部顯示「目前離線」
5. 重試邏輯：指數退避（1s → 2s → 4s → ... → 60s max）
```

**驗收標準**：
- 本地寫入 → sync_queue 有記錄
- 有網路時自動 push
- pull 可接收雲端變更
- 離線時 Banner 顯示

---

### B18. 基礎埋點

**預估**：1 天
**前置條件**：B3 完成

```
任務：
1. 整合 PostHog iOS SDK（或 TelemetryDeck）
2. 追蹤核心事件：
   - onboarding_completed { language, accent, voice_id }
   - recording_made { category, has_starter }
   - listen_completed { sentence_id, listen_count, predict_correct }
   - quiz_evaluated { sentence_id, result }
   - vocab_added { word, source }
   - preview_completed
3. 追蹤用戶屬性：learning_language, accent_preference, subscription_tier
4. 設定 Super Properties：app_version, ios_version, device_model
```

**驗收標準**：
- PostHog Dashboard 可看到事件
- 核心事件在對應操作時觸發
- 用戶屬性正確

---

## 工作流 C：寵物動畫資產

### C1. 動畫方案決策

**預估**：0.5 天
**前置條件**：開發啟動時立即決定
**時間點**：Sprint 1

```
決策選項：
A. SwiftUI 原生動畫（推薦 MVP）
   - 優勢：零外部依賴、零學習成本、完全可控
   - 劣勢：複雜動畫實現困難
   - 適合：P0 基礎動畫（漂浮、眨眼、搖擺、跳躍）

B. Lottie（推薦補充）
   - 優勢：After Effects 製作 → JSON 導出 → 高品質
   - 劣勢：需要 After Effects 技能、lottie-ios SDK
   - 適合：P1/P2 複雜動畫（慶祝、花瓣飄落）

C. Rive
   - 優勢：互動式狀態機、即時參數控制
   - 劣勢：學習曲線較陡、rive SDK
   - 適合：未來版本寵物互動增強
```

**建議**：MVP 用 A + B 混合。基礎動畫用 SwiftUI，5-10 個關鍵慶祝動畫用 Lottie。

---

### C2. 寵物角色定稿

**預估**：1 天
**前置條件**：C1 決策完成

```
任務：
1. 基於 pet-concept-C.png 的方向，生成 4 個裝飾階段的高品質角色圖：
   - Stage 0 (none)：純種子
   - Stage 1 (sprout)：種子 + 小葉芽
   - Stage 2 (leaf)：種子 + 大葉子
   - Stage 3 (bud)：種子 + 大葉子 + 花苞
   - Stage 4 (bloom)：種子 + 大葉子 + 盛開花朵
2. 每張圖輸出：
   - PNG（透明背景，512x512）
   - SVG（用於 Lottie 製作）
3. 確保 5 張圖的角色一致（同一個種子，只是裝飾不同）
```

---

### C3. Lottie 動畫製作

**預估**：2-3 天
**前置條件**：C2 完成
**時間點**：Sprint 3-4（在 B14 之前完成）

```
任務：
1. 選擇 8-10 個最關鍵的動畫用 After Effects + Bodymovin 製作：
   - gentle-float（基礎漂浮）
   - quiz-good（開心跳躍）
   - quiz-fail（下沉安慰）
   - rec-done（錄音完成歡呼）
   - listen-complete（聆聽完成慶祝）
   - welcome-back（回歸歡迎）
   - bloom-appear（開花瞬間）
   - petal-scatter（花瓣飄落）
2. 導出為 Lottie JSON
3. 測試在 iOS 上播放正常
```

---

## 工作流 D：發布準備

### D1. App Store 素材

**預估**：1 天
**時間點**：Sprint 5

```
任務：
1. App 截圖（真實設備）：
   - 6.7 寸（iPhone 15 Pro Max）× 5 張
   - 5.5 寸（iPhone 8 Plus）× 5 張
   - 畫面：今日頁面 / 錄音頁面 / 聆聽 4 步 / Quiz 翻卡 / 筆記頁面
2. App 描述文案（中文 + 英文）
3. 關鍵詞（100 字元以內）
4. 分類選擇：Education
```

---

### D2. 隱私政策

**預估**：0.5 天

```
任務：
1. 撰寫隱私政策（涵蓋：收集的數據、用途、第三方服務、用戶權利）
2. 發布到可公開存取的 URL（GitHub Pages 或 Notion）
3. URL 填入 App Store Connect
```

---

### D3. TestFlight 測試

**預估**：1-2 週（等待期）

```
任務：
1. Xcode Cloud / GitHub Actions 自動構建 → TestFlight
2. 邀請 3-5 個測試用戶
3. 收集反饋（問卷或訪談）
4. 記錄 bug 和體驗問題
```

---

### D4. Bug 修復

**預估**：3-5 天

```
任務：
1. 根據 TestFlight 反饋修復 P0 bug
2. 修復體驗問題（動畫卡頓、佈局異常等）
3. 補充遺漏的錯誤處理
```

---

### D5. App Review 提交

**預估**：0.5 天 + 1-3 天等待

```
任務：
1. App Store Connect 填寫所有資訊
2. 上傳截圖 + 描述 + 關鍵詞
3. 提交審核
4. 處理審核反饋（如有）
```

---

## 執行順序與依賴圖

```
用戶準備（P1-P4）
  │
  ├─→ A1 Supabase 專案
  │     ├─→ A2 Schema
  │     │     ├─→ A3 RLS
  │     │     ├─→ A6 Sync functions
  │     │     └─→ A7 種子句數據 → A8 種子句音頻
  │     └─→ A4 Auth
  │           └─→ A5 recording/process → A9 Prompt 工程
  │
  ├─→ B1 iOS 初始化 ←── C1 動畫方案決策
  │     ├─→ B2 Auth UI
  │     │     └─→ B3 Onboarding ←── A7, A8
  │     │           ├─→ B4 錄音頁面
  │     │           │     └─→ B5 錄音核心 ←── A5
  │     │           │           ├─→ B6 詞彙存檔
  │     │           │           ├─→ B7 聆聽骨架
  │     │           │           │     ├─→ B8 盲聽+預測
  │     │           │           │     │     └─→ B9 拆解+跟讀
  │     │           │           │           └─→ B10 Quiz
  │     │           │           └─→ B11 夜間預覽
  │     │           ├─→ B12 筆記頁面
  │     │           ├─→ B13 寵物系統 → B14 寵物動畫 ←── C3
  │     │           ├─→ B15 智能推薦+教練
  │     │           ├─→ B16 設定
  │     │           └─→ B18 埋點
  │     └─→ B17 離線同步
  │
  └─→ C2 角色定稿 → C3 Lottie 製作
                          │
  D1 App Store 素材 ←─────┘
  D2 隱私政策
  D3 TestFlight → D4 Bug 修復 → D5 提交審核 → 🚀
```

**關鍵路徑**（最長的依賴鏈）：
```
A1 → A2 → A7 → A8 → B3 → B4 → B5 → B7 → B8 → B9 → B10 → B15 → D3 → D4 → D5
```

---

## 技術棧總結

| 層級 | 方案 |
|------|------|
| 前端 | SwiftUI (iOS 17+) |
| 本地數據庫 | SQLite (GRDB.swift) |
| 本地音頻存儲 | FileManager (Documents/audio/) |
| 語音辨識 | iOS Speech Framework (SFSpeechRecognizer) |
| 後端 | Supabase (Auth + PostgreSQL + Edge Functions) |
| AI 翻譯 | GPT-5.4 Mini (OpenAI API) |
| TTS | OpenAI TTS tts-1 (4 聲線) |
| 種子句音頻 CDN | Cloudflare R2 |
| 分析 | PostHog 或 TelemetryDeck |
| CI/CD | Xcode Cloud 或 GitHub Actions → TestFlight |
| 動畫 | SwiftUI 原生 + Lottie (關鍵動畫) |
