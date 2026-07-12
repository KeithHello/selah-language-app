# Selah M3 CI 修復概覽

## 已完成

本輪修復了 GitHub Actions 中剩餘的 M3 測試失敗，包含 ReviewState 間隔斷言、四種 VoiceProfile 測試、GeneratedAudioResult readiness 契約，以及 AudioCacheService protected URL 的標準化比對。

## 主要決策

ReviewState 以目前 v8/M3 實作為準：learning + clear 為 3 天，familiar + clear 進入 quiet 為 7 天；ready 音頻結果必須提供有效 download URL，符合私有 Storage signed URL 流程。

## Git 狀態

修復已提交並推送至 `origin/main`：

- `06b3472`：對齊 M3 測試契約與音頻快取保護邏輯
- `cde8ca2`：修正完整復習生命周期的間隔斷言

最後一次 GitHub Actions `Build & Test` 已成功：run `29196108394`，215 tests 執行，1 skipped，0 failures。