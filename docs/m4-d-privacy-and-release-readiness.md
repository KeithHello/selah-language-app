# Selah M4-D 隱私與發布準備

> 狀態：核心文件與可驗證邊界已完成。真實 iOS 權限、Xcode target 與 App Store Connect 驗收仍需 Apple Developer 與 macOS Xcode 環境。

## 1. 隱私承諾

Selah 的學習資料以「先保存在使用者裝置」為核心。使用者輸入的中文句子只在使用翻譯功能時送往 Selah 後端，再由後端呼叫翻譯服務；App 不直接把 provider key 放在用戶端。音訊生成只傳送產生英文音訊所需的英文句子與聲線設定，生成後音訊存放於私有 Supabase Storage，透過短期 signed URL 取用。

Selah 的學習事件只記錄必要的行為類型與最小 metadata，不應記錄原始中文句子、完整英文句子、錄音檔或 API key。Widget-ready 摘要與本地通知文案不包含個人句子內容。

## 2. 資料分類與用途

| 資料 | 用途 | 儲存位置 | MVP 保留原則 |
|---|---|---|---|
| 使用者輸入句子與生成教材 | 翻譯、聆聽、複習 | 本機 SwiftData；後端僅在請求處理與既定資料流使用 | 不進日誌；刪除本機資料即可移除本機副本 |
| 語音輸入 | 將語音轉成中文草稿 | iOS Speech framework 流程 | App 不自行保存原始錄音；真機驗收需確認系統語音資料流 |
| 音訊檔與 manifest | 播放、快取、重試與完整性驗證 | 本機 Application Support；後端私有 Storage | 本機快取採 100 MB LRU；可由設定入口清除 |
| 學習事件 | 推薦與產品品質分析 | 後端 learning_events | 事件白名單、metadata 僅允許 primitive 值，不保存句子文字 |
| 帳號與 session | 登入與 API 授權 | Supabase Auth；App session 由 App 管理 | 不把 token 寫入日誌或產品文案 |
| 使用量紀錄 | 成本與反濫用分析 | 後端 usage_records | 僅記 operation type、user id 與估算 units |

## 3. 權限說明

麥克風／語音識別權限只在使用語音輸入時請求，拒絕後仍可使用文字輸入。通知權限只用於每日學習提醒，關閉後取消排程，不影響核心學習功能。網路權限用於翻譯、音訊生成與同步必要服務；離線時保留本機句子與待處理音訊工作，不把離線操作偽裝成已完成。

正式 iOS target 建立後，必須補上 `NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription` 與通知權限流程的使用者說明，並在真機確認拒絕、重新授權及系統設定導引。

## 4. 日誌脫敏規則

產品執行期不得輸出 raw sentence、target text、語音內容、Authorization header、API key、refresh token、完整 provider response body 或完整底層錯誤描述。服務端只記錄狀態碼、內部錯誤代碼與 request correlation id；公開回應只返回產品安全錯誤代碼與通用文案。

目前 Edge Functions 已在翻譯解析失敗時避免把 provider 回應放入 HTTP 回應；後續部署前需確認平台日誌不會收集 request body，並將錯誤日誌維持為狀態／錯誤碼級別。App 層對使用者採用 `safeUserMessage`，不得直接顯示 `LocalizedError` 的底層 provider 文本。

## 5. SwiftData migration policy

MVP 先採「明確 schema 版本 + additive migration 優先」：新增 optional 欄位或有預設值欄位先使用輕量 migration；需要重命名、刪除欄位或改變語義時建立新的 `Schema.VersionedSchema` 與 `SchemaMigrationPlan`，不在啟動時默默刪除資料。每個 schema 變更都要有 fixture migration test，並在升級前備份或保留本機可恢復資料路徑。

目前 repository 是可供 Package CI 驗證的 SwiftData 核心層，尚未建立完整 Xcode iOS target，因此 migration plan 的真機升級測試仍是發布前必要項，不宣稱已完成。

## 6. Provider fallback policy

MVP 不在 iOS 端直接切換 provider。所有翻譯與 TTS 呼叫經由 Supabase Edge Functions；M4-A 已完成 typed errors、bounded retry 與 capability circuit breaker。若主要 provider 持續失敗，服務端應回傳通用暫時不可用錯誤，保留句子與 GenerationJob，不把未驗證的替代結果寫入教材。

Provider fallback 只有在替代 provider 的資料保留、輸出格式、成本、語音一致性與安全審查完成後才可啟用。現階段 fallback 是「安全保留並稍後重試」，不是未驗證的自動換供應商。

## 7. BGTaskScheduler 邊界

GenerationJob 已持久化並支援恢復、到期重試與 online-only 執行。真正的 `BGTaskScheduler` 需要 Xcode iOS target、Background Modes、task identifier、系統排程註冊與約 30 秒預算；不能在目前 Swift Package 中假裝已完成。背景 task 應採短批次、可中斷、每次保存狀態，超時後由下一次啟動／回到前景繼續。

## 8. Apple Privacy Nutrition Label 草案

提交 App Store Connect 前，依實際版本與服務設定確認：App Functionality 可能涉及帳號資訊、使用者輸入內容、音訊／語音輸入、診斷與使用量事件；每項都要標示用途、是否與使用者連結及是否用於追蹤。若某資料只在請求處理期間傳輸且不保存，仍需依 Apple 當期問卷規則判斷是否申報，不可用「未保存」自行省略。

## 9. 已完成的工程收尾

本階段已完成 App 與 Edge Functions 的敏感錯誤脫敏：用戶端不再把底層 provider payload、token refresh reason、網路錯誤描述或 SwiftData／播放錯誤直接放進產品錯誤文案；服務端只記錄狀態級錯誤，不記錄 provider response body、生成內容或 Supabase 錯誤 message。相關回歸測試已覆蓋 API 錯誤文案不洩漏原始 payload。

Provider fallback 的 v1 決策是「保留本機資料與 GenerationJob，稍後重試」，不啟用未完成審查的自動換供應商。BGTaskScheduler 仍明確保留為 Xcode iOS target 階段工作，不在 Swift Package 中偽造完成。SwiftData migration policy 已定義為版本化 schema、additive migration 優先，破壞性變更需 `VersionedSchema`、`SchemaMigrationPlan` 與 fixture 測試。

## 10. M5 開始條件

M5 可以開始準備文件與設計資產，但 TestFlight 實際發布前必須先具備 Apple Developer 帳號、可編譯的 Xcode iOS target、Bundle ID／簽名設定、隱私政策公開 URL、App Icon、App Store 截圖與可重現的 release build。