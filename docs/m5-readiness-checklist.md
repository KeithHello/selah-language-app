# Selah M5 啟動前檢查表

> 狀態：可以開始準備 M5 文件與設計資產；尚未具備 TestFlight／App Store 實際提交條件。

## 已確認的工程基線

- M4-A 可靠性、M4-B 離線優先與 M4-C 使用者體驗核心層已有 GitHub Actions 驗證紀錄。
- M4-C／M4-D 核心层已推送；GitHub Actions run `29339236287` 在 HEAD `0eb8c56` 通过。
- 该 CI 只验证 macOS Swift Package，不验证 iOS App target、Deno 测试或已部署 Edge Functions。
- v1 的 provider fallback 決策為保留本機資料與 GenerationJob 後續重試，不自動切換未審查的替代 provider。
- BGTaskScheduler、通知權限、WidgetKit、Dynamic Type 全螢幕審計與 VoiceOver 真機巡檢，均需要真正的 Xcode iOS target 與裝置驗證。

## M5 啟動前必做

- 更新并执行 Supabase Edge Function 行为测试，将 Deno 测试加入 CI。
- 建立可編譯的 Xcode iOS target，確認 Bundle ID、Signing、最低 iOS 版本、Info.plist 權限說明與正式環境 endpoint。
- 建立版本化 SwiftData schema；針對升級、空資料、失敗恢復與資料保留完成 fixture／裝置測試。
- 實作並驗收 BGTaskScheduler 短批次重試；確認離線、超時、被系統中斷與回到前景後的恢復行為。
- 完成通知權限、語音識別權限、音訊快取清理、帳號登出與資料刪除流程的真機驗收。
- 完成 WidgetKit Extension 接線；只顯示 `WidgetReadySnapshot` 的非敏感摘要。
- 產出 App Icon、App Store 截圖、公開隱私政策 URL 與 Apple Privacy Nutrition Label 問卷答案。

## M5 交付順序

先做 Xcode target 與可重現 release build，再做 TestFlight 內測；通過真機回歸、隱私檢查與崩潰／日誌審查後，才準備 App Store Connect 提交。
