# Selah M4-A 可靠性核心概覽

## 已完成

已加入網路錯誤分類、產品安全錯誤訊息、三次有界重試、Retry-After 支援、句子生成與音頻生成的獨立熔斷器，以及 GenerationRetryQueue 的中斷任務恢復與 App foreground 觸發。

## 主要檔案

`Selah/Core/Networking/Reliability.swift` 定義可靠性能力、錯誤種類、RetryPolicy 與 actor-isolated CapabilityCircuitBreaker。

`Selah/Core/Networking/SelahAPIClient.swift` 接入三次重試、401 只刷新一次 Token、HTTP 狀態分類與獨立能力熔斷。

`Selah/Core/GenerationRetryQueueImpl.swift` 和 `Selah/Core/Repositories/GenerationJobRepositoryImpl.swift` 接入到期任務限制、最多每次處理 3 件、in-progress 恢復和熔斷降級。

`Selah/SelahApp.swift` 在初始化與回到 foreground 時恢復並處理待生成任務。

`SelahTests/M4ReliabilityTests.swift` 覆蓋重試排程、HTTP／網路錯誤分類和熔斷狀態轉移。

## 驗證與提交

已通過 `git diff --check`，本機沒有 Swift toolchain，因此無法執行 Swift tests。變更已提交並推送：`91c2a89 feat: 实现 M4-A 可靠性核心`。

GitHub Actions `Build & Test` run `29255207172` 已啟動，待確認完成後才可將 M4-A 標記為 CI 完成。

## 後續

若 CI 通過，下一步是按既定順序進入 M4-B 離線優先；若 CI 失敗，先修復編譯或回歸測試，再繼續 M4。
