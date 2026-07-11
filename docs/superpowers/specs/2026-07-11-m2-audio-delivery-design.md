# Selah M2：音頻交付、快取與真實聆聽設計

**日期**：2026-07-11  
**狀態**：待主人審閱  
**決策**：採用 A 方案——Supabase Storage 私有 bucket、按需下載、iOS 本地快取。

## 1. 目標與完成定義

M2 讓 Selah 從「句子已生成」變成「可以可靠聽、可離線聽、可以練」。使用者建立句子後，不必等待 TTS 完成才能保存；音頻在背景生成、下載並快取。已下載的音頻在無網路時仍可播放。

M2 完成時，使用者能以四種聲線播放英文句子，使用 0.7x、0.85x、1.0x、1.2x 速度，使用 A-B 循環重複指定片段，並從真實資料中完成「盲聽→猜測→拆解→跟讀」四步聆聽。系統需避免重複 TTS 計費、避免損壞檔案、可安全重試失敗工作。

本階段不做 App Store 上傳、真機背景模式最終驗收、Lottie/Rive 動畫或 Widget；這些屬於後續 M4/M5 或 Xcode 真機驗收。

## 2. 已知現況與必修正項

目前 `audio-generate` Edge Function 回傳 base64 音頻巢狀物件，但 iOS `GeneratedAudioResult` 預期扁平的 URL/路徑欄位，兩者不相容。M2 必須以 Storage URL manifest 取代 base64，避免大音檔進 JSON、記憶體峰值與解碼不一致。

目前 iOS AppState 預設使用 Mock sentence/audio services。M2 會將服務注入調整為依 Session 切換：已登入時用真實 API service；未登入或網路不可用時保留 mock/離線內容的可預測 fallback。這項修正屬於音頻端到端驗收必要條件。

## 3. 後端設計

### 3.1 Storage bucket 與路徑

建立私有 bucket：`audio-assets`。不使用 public URL。Edge Function 只發出短效 signed URL，App 不持有 service role key。

種子音頻路徑：

```text
seed/{seedSentenceId}/{voiceProfile}/{contentHash}.mp3
```

使用者音頻路徑：

```text
users/{userId}/{sentenceId}/{voiceProfile}/{contentHash}.mp3
```

`contentHash` 是 SHA-256 of `normalizedEnglishText + voiceProfile + ttsModel + speed + audioFormat`。其中英文正規化使用 trim、空白折疊與小寫化。不同文字、聲線、模型、速度或格式必然產生新檔；完全相同的請求命中既有物件。

### 3.2 音頻 manifest

新增 `audio_manifests` 資料表。它是 TTS 去重與 Storage metadata 的來源，不是 iOS 本地快取的替代品。

核心欄位為：`id`、`owner_user_id`（種子音頻為 null）、`sentence_id`（使用者句子可關聯）、`seed_sentence_id`、`voice_profile`、`content_hash`、`storage_path`、`tts_model`、`speed`、`audio_format`、`byte_size`、`duration_ms`、`sha256`、`generation_status`、`error_code`、`created_at`、`updated_at`、`last_accessed_at`。

唯一約束：`(scope, content_hash)`，其中 scope 是 seed 或 owner user id。這避免不同使用者意外共用私人句子，也讓公開 seed 音頻可安全共用。

### 3.3 RLS 與 Edge Function 權限

種子 manifest 僅供已登入使用者讀取，使用者 manifest 僅允許其 owner 存取。Storage object 的直接 select 不對客戶端開放；音頻讀取由 Edge Function 驗證 JWT、驗證 manifest 所屬範圍後產生短效 signed URL。

`audio-generate` 的責任為：驗證 JWT、驗證輸入長度與聲線、計算 content hash、查 manifest。如果 ready manifest 存在，直接返回 manifest 與 signed URL；如果不存在，建立或鎖定 generating manifest，呼叫 OpenAI TTS，將 MP3 上傳 Storage，計算 SHA-256 和時長，更新 manifest 為 ready，再返回結果。失敗時更新為 failed，回傳可安全重試的錯誤碼。

新增 `audio-download-url` Function，只負責對既有 ready manifest 生成短效 signed URL；不觸發 TTS。

### 3.4 響應合約

iOS 後端音頻響應統一為：

```json
{
  "status": "ready",
  "voiceProfile": "gentle-natural",
  "manifestId": "uuid",
  "downloadUrl": "https://...signed...",
  "storagePath": "users/.../hash.mp3",
  "sha256": "hex",
  "byteSize": 12345,
  "durationMs": 3400,
  "cacheHit": false,
  "expiresAt": "2026-07-12T...Z"
}
```

`queued` 或 `generating` 時不提供 downloadUrl；`failed` 回傳穩定 `errorCode`。iOS Codable DTO 與此合約一一對齊。

## 4. 種子句預生成策略

預生成 30 句 × 4 聲線，即 120 個 MP3：nova、sage、ash、shimmer。生成腳本讀取 `SeedContent/seed-sentences.json`，以固定模型 `tts-1`、固定學習速度 0.85x 產生音頻，計算 hash，透過受控後端或管理憑證寫入 Storage/manifest。

Onboarding 完成後，App 僅預取使用者所選的 3 句與當前聲線，不預下載全部 120 檔。其他 seed 音頻按需下載；已下載音頻可離線使用。

腳本必須具備 dry-run、按 hash 跳過已存在檔案、逐檔失敗報告、可重跑與不把任何 key 寫入版本庫。真正呼叫 OpenAI 並產生 120 支音檔會消耗 API 額度，因此只在主人確認執行批次生成時運行。

## 5. iOS 音頻基礎設施

### 5.1 AudioCacheService

新增 `AudioCacheService`（actor）。存放位置為 Application Support 的 `SelahAudio/`，不使用 Documents，避免把可再生快取暴露給使用者檔案共享。

下載採用臨時檔後原子 move。驗證順序：HTTP 成功、最小 MP3 byte 數、SHA-256 比對、檔案存在。任何驗證失敗都刪除臨時檔且不將 AudioAsset 標為 ready。

上限為 100 MB。每次寫入前與 App 啟動時進行 LRU 清理。LRU 以 `AudioAsset.downloadedAt` 和新設的 `lastPlayedAt` 判定；正在播放、queued 或 generating 的音檔不可刪。清理後無法釋放足夠空間時，保留現有快取並返回可理解的 storage error。

### 5.2 AudioPlaybackService

新增 AVFoundation 實作，支援本地 URL 播放、暫停、停止、progress、duration、速度切換、A-B loop、音頻中斷與路由變化。播放速度只允許 `PlaybackSpeed` enum 的四檔；A-B 值需滿足 `0 <= A < B <= duration`，無效值不啟動 loop。

音頻播放不會以重新呼叫 TTS 來實現速度變化。使用 AVAudioPlayer rate，避免不必要成本與重複檔案。

### 5.3 AudioAsset 狀態機與重試

合法狀態轉移：

```text
queued -> generating -> ready
queued -> failed
generating -> failed
failed -> queued  （手動或排程重試）
ready -> queued   （明確要求重新生成且內容／聲線／模型變更）
```

`GenerationJob` 對 failed 音頻採現有指數退避策略。使用者點「重新生成」時建立或重設一個 audio regeneration job，不覆蓋現有可播放檔案，直到新檔驗證成功才切換 asset reference。

## 6. 聆聽集與 UI 整合

`ListenCollectionBuilder` 從 SwiftData 取得可用句子：音頻 ready、未 archived、尚未完成或需要複習。預設最多 3 句，優先順序為今日新句→之前 preview 過但未聽→due 的 learning 句。沒有可聽句子時顯示明確 empty state，而不是 mock 句子。

ListenView 依序實作四步：盲聽三遍、使用者先猜、展示英文和拆解、跟讀。進度在實際播放完成後才前進；完成後寫入 `listenCompletedAt`、ReviewState、LearningEvent，讓 Practice 只取已聽過的句子。

TodaySentenceView 保存新句後不阻塞等待音頻。如果音頻未完成，Today 顯示「語音準備中」；成功後可進聆聽，失敗時顯示「重新生成語音」。

## 7. 失敗模式與使用者體驗

- 無網路且本地已有音頻：直接播放。
- 無網路且未快取：顯示「這句還沒下載，連線後再試」，不建立失敗 TTS job。
- TTS provider 失敗：句子仍已保存，AudioAsset 為 failed，可手動重試。
- signed URL 過期：重新請求 `audio-download-url`，不重新 TTS。
- 下載中斷：臨時檔刪除，下次重新下載；不會播放半檔。
- 快取清理：永遠不刪除正在播放的檔案。
- 系統音頻中斷：暫停、記錄 position；恢復時只在中斷前是播放狀態才提示續播。

## 8. 測試與驗收

單元測試覆蓋 hash 一致性／差異性、DTO decode、狀態轉移、重試指數退避、LRU、cache 原子寫入失敗、SHA mismatch、聆聽集合優先級、A-B 合法範圍、速度枚舉與手動重生成。

Supabase Deno 測試覆蓋 path builder、manifest scope、response schema、非法聲線、cache hit、signed URL 無權限拒絕與 seed manifest read policy。

CI 包含 Swift Package build/test、Deno test 與不含 secrets 的 static validation。GitHub Actions 通過不是 iOS 真機音頻驗收的替代品。

真機驗收必須在 Xcode 完成：SFSpeech/Microphone permissions、AVAudioSession、耳機插拔、電話／鬧鐘中斷、Background Audio mode、低儲存空間、斷網重連與真實 seed 預取。

## 9. 實作順序

1. 修正 M1 真實 API Session 注入與音頻 response contract。
2. 建立 manifest migration、Storage policy、audio-generate 去重與 audio-download-url。
3. 實作 iOS DTO、AudioCacheService、AudioPlaybackService、retry integration。
4. 實作 ListenCollectionBuilder，將 Listen/Practice/Today 接真實資料。
5. 補測試、跑 CI、修復編譯／測試問題。
6. 產生並上傳 120 支種子音頻（需主人在執行前確認費用消耗）。
7. 在 Mac/Xcode 做真機驗收；將帳號／簽名／背景模式結果寫入 release checklist。

## 10. 明確不在本階段的範圍

App Icon、App Store 截圖、TestFlight 上傳、正式發佈、Widget、通知、完整離線文字同步、Provider 熔斷與 Lottie/Rive 動畫均不屬於 M2。本階段只提供可由後續 M3/M4/M5 使用的可靠音頻能力。
