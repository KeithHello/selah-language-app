# Selah M4-B 離線優先概覽

## 已完成

M4-B 已加入可注入、actor-isolated 的連線狀態監測，支援 `unknown`、`offline` 和 `online`，並以 `#if canImport(Network)` 保持 Swift Package／macOS CI 相容。

Today Sentence 翻譯在離線時不再呼叫遠端服務，保留中文輸入並以繁體中文待處理訊息提示使用者。句子保存後，音訊資產維持 `queued`，同時建立 GenerationJob，等待連線恢復後由 M4-A 的前景重試隊列處理；既有本地學習資料不會因網路中斷被回滾或刪除。

AppState 在初始化與回到 foreground 時更新連線狀態，只有在線時才處理到期的音訊生成任務。

## 測試與修正

新增 `SelahTests/M4OfflineFirstTests.swift`，覆蓋連線狀態注入、離線翻譯不呼叫遠端服務，以及待處理訊息的繁體中文安全文案。

首次 CI 發現 XCTest 不支援在同步 autoclosure 中直接使用 `await`，並發現 SwiftData `ModelContainer` 配置需要 variadic 參數；後續又修正了 MainActor 隔離的 `translate` 呼叫。這些修正已分別記錄於 `4bea12f` 和 `5a065ce`。

## 驗證結果

GitHub Actions `Build & Test` run `29258705736` 已成功，Build 與 Test 均通過。最新提交為 `5a065ce fix: 修正 M4-B 主线程测试调用`，遠端分支為 `origin/main`，工作樹 clean。

## 後續

M4-B 可標記完成。下一階段按既定順序進入 M4-C：本地通知、Widget-ready 摘要、VoiceOver／Dynamic Type／Reduce Motion 等使用者體驗加固；隱私政策仍放在 M4-D，暫不與 M4-C 混做。