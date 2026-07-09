# Selah — 開工前設計文件（Engineering Kickoff）

> **App 名稱**：Selah（希伯來文 סֶלָה，意為「停下來、默想、聆聽」）
> **版本**：v1.0 | **日期**：2026-06-26
> **依據**：`language-island-prd.md`（PRD v1.2）/ `language-learning-system-design.md`（設計藍圖 v1.1）
> **技術棧**：SwiftUI 原生（iOS Phase 1）

---

## 目錄

1. [專案概述](#一專案概述)
2. [技術架構分層](#二技術架構分層)
3. [核心資料模型](#三核心資料模型)
4. [模組邊界與介面（Protocols）](#四模組邊界與介面protocols)
5. [寵物系統：四維度與練習行為綁定](#五寵物系統四維度與練習行為綁定)
6. [里程碑交付範圍（M0–M3）](#六里程碑交付範圍m0m3)
7. [關鍵技術決策記錄（ADR）](#七關鍵技術決策記錄adr)
8. [Xcode 專案結構建議](#八xcode-專案結構建議)
9. [外部依賴清單](#九外部依賴清單)
10. [開放問題與待確認項](#十開放問題與待確認項)

---

## 一、專案概述

### 1.1 一句話

Selah 是一款以「用戶真實生活中會說的話」為唯一學習原點的 iOS App，搭配一隻與學習狀態共生的語言精靈（寵物），透過「盲聽 → 預測 → 跟讀 → 檢測」的肌肉記憶迴圈，幫用戶從零走到真實流利。

### 1.2 技術棧決策摘要

| 決策 | 選擇 | 理由 |
|------|------|------|
| **UI 框架** | SwiftUI | 原生、聲明式、與 iOS 生態無縫整合 |
| **語言** | Swift 5.9+ | 強型別、actor 模型支援併發安全 |
| **資料持久化** | SwiftData | Apple 原生 ORM，與 SwiftUI 深度整合，支援 CloudKit 同步 |
| **語音識別** | SFSpeechRecognizer | iOS 原生，低延遲即時轉錄，無 bridge 開銷 |
| **TTS** | ElevenLabs API + AVAudioPlayer | 高品質自然語音 + 原生播放器控制 |
| **背景音訊** | AVAudioSession + MPRemoteCommandCenter | 鎖屏控制、耳機按鍵、中斷續播 |
| **推播** | UserNotifications | 本地 + 遠端推播 |
| **Haptics** | UIFeedbackGenerator（封裝） | 觸覺回饋 |
| **動畫** | Lottie + SwiftUI Animation | 寵物動畫 + UI 過渡 |
| **網路層** | URLSession + async/await | 原生，零第三方依賴 |
| **架構模式** | MVVM + 業務邏輯層隔離 | UI 與邏輯解耦，邏輯可跨平台 |

### 1.3 跨平台策略

```
┌─────────────────────────────────────┐
│  UI 層（SwiftUI / 未來 Android UI） │  ← 平台相關，不共享
├─────────────────────────────────────┤
│  業務邏輯層（Swift Package）        │  ← 平台無關，KMP 可共享
│  - XP 計算引擎                      │
│  - Smart Excel 排程引擎             │
│  - 寵物狀態機                       │
│  - 題材推薦權重                     │
│  - 六階段里程碑判定                 │
├─────────────────────────────────────┤
│  資料層（Repository 介面）          │  ← 介面統一，實作平台相關
│  - SwiftData（iOS）                │
│  - Room/Realm（Android 預留）      │
├─────────────────────────────────────┤
│  外部服務層（Protocol 抽象）        │  ← 介面統一，實作可替換
│  - ITTSProvider（ElevenLabs）      │
│  - ISpeechRecognition（SF...）     │
│  - ITranslationService（AI 模型）  │
└─────────────────────────────────────┘
```

**原則**：業務邏輯層不 import UIKit / SwiftUI / Foundation 以外的平台框架。所有外部服務透過 protocol 注入，可 mock、可替換。

---

## 二、技術架構分層

### 2.1 四層架構

```
┌──────────────────────────────────────────────────────┐
│                    Presentation Layer                 │
│  SwiftUI Views + ViewModels + Navigation             │
│  職責：畫面渲染、用戶互動、動畫、狀態顯示              │
├──────────────────────────────────────────────────────┤
│                    Domain Layer                       │
│  Use Cases + Entities + Domain Services              │
│  職責：業務規則、XP 計算、排程、狀態機、里程碑判定     │
│  約束：不依賴 UI 框架、不依賴具體資料實作              │
├──────────────────────────────────────────────────────┤
│                    Data Layer                         │
│  Repositories + Data Sources + DTOs                  │
│  職責：資料存取、快取策略、資料轉換（Entity ↔ DTO）    │
├──────────────────────────────────────────────────────┤
│                    Infrastructure Layer               │
│  API Clients + System Services + Platform Bridges    │
│  職責：網路請求、SFSpeechRecognizer、AVAudioSession、 │
│       UserNotifications、File I/O                     │
└──────────────────────────────────────────────────────┘
```

**依賴方向**：Presentation → Domain ← Data → Infrastructure（Dependency Inversion）。Domain 層不知道 Data 和 Infrastructure 的存在，透過 protocol 注入。

### 2.2 各層具體職責

| 層 | 包含什麼 | 不包含什麼 |
|---|---------|-----------|
| **Presentation** | SwiftUI View、ViewModel（@Observable）、NavigationStack、動畫 | 業務邏輯、資料存取、API 呼叫 |
| **Domain** | Entity（struct）、UseCase、DomainService、Protocol 定義 | SwiftUI import、SwiftData、URLSession |
| **Data** | Repository 實作、SwiftData Model、DTO、Mapper | UI 邏輯、動畫、業務規則 |
| **Infrastructure** | ElevenLabsClient、SpeechRecognitionService、AudioSessionManager、NotificationService | 業務邏輯、UI 邏輯 |

---

## 三、核心資料模型

> 以下為 Domain 層的 Entity 定義（純 Swift struct），不依賴 SwiftData。Data 層會有對應的 SwiftData @Model 實作。

### 3.1 語料（CorpusItem）

```swift
struct CorpusItem: Identifiable, Codable {
    let id: UUID
    let userTextZH: String            // 用戶的中文原句
    let translatedText: String        // AI 翻譯的目標語言文本
    let targetLang: TargetLang        // .en / .ja
    let audioURL: URL?                // ElevenLabs 生成的音檔本地路徑
    let voiceId: String?              // 生成此句使用的音色 ID
    let emotionTag: EmotionTag        // 感情標籤
    let category: SceneCategory       // 六大場景分類
    let sourceTopicId: String?        // 來源題材 ID（若有）
    let reviewLevel: ReviewLevel      // Smart Excel 級別 L0-L5
    let lastReviewedAt: Date?         // 上次檢測時間
    let nextReviewAt: Date?           // 下次排程檢測時間
    let consecutivePassCount: Int     // 連續通過次數
    let totalPassCount: Int           // 總通過次數
    let totalFailCount: Int           // 總失敗次數
    let blindListenCount: Int         // 盲聽遍數
    let createdAt: Date
    let updatedAt: Date
}

enum TargetLang: String, Codable {
    case en, ja
}

enum EmotionTag: String, Codable, CaseIterable {
    case casual      // 輕鬆
    case formal      // 正式
    case upset       // 激動
    case gentle      // 溫柔
    case serious     // 認真
}

enum SceneCategory: String, Codable, CaseIterable {
    case workDaily      // 社畜日常 💼
    case friendChat     // 朋友幹話 💬
    case ventOut        // 先吐為快 💨
    case heartfelt      // 走心時刻 💕
    case standGround    // 據理力爭 🗣️
    case lifeQuest      // 生活闖關 🌍
}

enum ReviewLevel: Int, Codable {
    case L0 = 0   // Red Queue（每日優先）
    case L1 = 1   // 初次通過 → 3 天後
    case L2 = 2   // 短期穩固 → 7 天後
    case L3 = 3   // 中期穩固 → 14 天後
    case L4 = 4   // 長期穩固 → 30 天後
    case L5 = 5   // Mastered Pool（月度喚醒）
    
    /// 通過後升級的間隔天數
    var intervalDays: Int {
        switch self {
        case .L0: return 1   // 每天
        case .L1: return 3
        case .L2: return 7
        case .L3: return 14
        case .L4: return 30
        case .L5: return 30  // 月度喚醒
        }
    }
}
```

### 3.2 寵物（Pet）

```swift
struct Pet: Identifiable, Codable {
    let id: UUID
    var name: String                  // 用戶自命名
    var form: PetForm                 // 形態
    var totalXP: Int                  // 累積成長值
    var todayXP: Int                  // 今日已獲 XP（用於上限判定）
    var hunger: Double                // 飽食度 0-100
    var mood: Double                  // 心情 0-100
    var health: Double                // 健康 0-100
    var bond: Double                  // 親密度 0-100（隱藏）
    var overallStatus: PetStatus      // 整體狀態
    var lastActiveAt: Date            // 上次互動時間
    var streakDays: Int               // 連續達標天數
    var createdAt: Date
    
    // 計算屬性
    var xpToNextForm: Int {
        switch form {
        case .egg: return 50
        case .baby: return 300
        case .growing: return 1000
        case .mature: return 3000
        case .legendary: return .max
        }
    }
}

enum PetForm: Int, Codable, Comparable {
    case egg = 0        // 蛋
    case baby = 1       // 幼體
    case growing = 2    // 成長期
    case mature = 3     // 成熟期
    case legendary = 4  // 傳說型
    
    static func < (lhs: PetForm, rhs: PetForm) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PetStatus: String, Codable {
    case healthy    // 🟢 健康
    case low        // 🟡 低落
    case sick       // 🟠 生病
    case danger     // 🔴 危險
    case sleeping   // 💤 沉睡
}
```

### 3.3 XP 事件（XPEvent）

```swift
struct XPEvent: Identifiable, Codable {
    let id: UUID
    let type: XPEventType
    let xpValue: Int
    let hungerDelta: Double
    let moodDelta: Double
    let healthDelta: Double
    let bondDelta: Double
    let corpusItemId: UUID?     // 關聯的語料（若有）
    let timestamp: Date
}

enum XPEventType: String, Codable {
    case appOpen               // 打開 App（每日首次）
    case nightPreview          // 完成夜間預習
    case blindListen           // 盲聽 1 遍
    case predictionSuccess     // 盲聽預測成功
    case shadowRead            // 跟讀 1 遍
    case quizPass              // 檢測答對
    case quizFail              // 檢測答錯
    case dailyWin              // 完成 Daily Win
    case clinking              // 靈光乍現回報
    case corpusCreated         // 語料產出
    case streakBonus           // 連續 Streak 達標
    case rescueMission         // 完成急救任務
}
```

### 3.4 XP 事件配置表（後台可調）

```swift
/// Domain Service：管理所有 XP 事件的數值配置
/// 所有數值後台可配置，此為預設值
struct XPEventConfig {
    static let table: [XPEventType: XPEventDelta] = [
        .appOpen:           .init(xp: 1,  hunger: 0,   mood: 2,   health: 0, bond: 0),
        .nightPreview:      .init(xp: 8,  hunger: 5,   mood: 3,   health: 0, bond: 0),
        .blindListen:       .init(xp: 2,  hunger: 1,   mood: 0,   health: 0, bond: 0),
        .predictionSuccess: .init(xp: 20, hunger: 3,   mood: 8,   health: 0, bond: 1),
        .shadowRead:        .init(xp: 5,  hunger: 3,   mood: 2,   health: 0, bond: 0),
        .quizPass:          .init(xp: 15, hunger: 10,  mood: 5,   health: 0, bond: 0),
        .quizFail:          .init(xp: 3,  hunger: 0,   mood: 0,   health: 0, bond: 0),
        .dailyWin:          .init(xp: 12, hunger: 0,   mood: 15,  health: 0, bond: 1),
        .clinking:          .init(xp: 25, hunger: 0,   mood: 20,  health: 0, bond: 2),
        .corpusCreated:     .init(xp: 6,  hunger: 3,   mood: 2,   health: 0, bond: 0),
        .streakBonus:       .init(xp: 5,  hunger: 0,   mood: 0,   health: 0, bond: 0.5),
        .rescueMission:     .init(xp: 30, hunger: 0,   mood: 20,  health: 40, bond: 0),
    ]
    
    /// 每日 XP 上限
    static let dailyXPCap = 200
    
    /// 靈光乍現不受上限限制
    static let exemptFromCap: Set<XPEventType> = [.clinking]
}

struct XPEventDelta {
    let xp: Int
    let hunger: Double
    let mood: Double
    let health: Double
    let bond: Double
}
```

### 3.5 Smart Excel 排程模型

```swift
/// Smart Excel System 排程引擎（Domain Service）
/// 職責：根據檢測結果計算下次複習時間和級別
struct ReviewScheduler {
    
    /// 檢測通過：升級
    static func onPass(item: CorpusItem) -> CorpusItem {
        var updated = item
        let newLevel = ReviewLevel(rawValue: min(item.reviewLevel.rawValue + 1, 5))!
        updated.reviewLevel = newLevel
        updated.consecutivePassCount += 1
        updated.totalPassCount += 1
        updated.lastReviewedAt = Date()
        updated.nextReviewAt = Calendar.current.date(
            byAdding: .day, value: newLevel.intervalDays, to: Date()
        )
        return updated
    }
    
    /// 檢測失敗：回退 L0
    static func onFail(item: CorpusItem) -> CorpusItem {
        var updated = item
        updated.reviewLevel = .L0
        updated.consecutivePassCount = 0
        updated.totalFailCount += 1
        updated.lastReviewedAt = Date()
        updated.nextReviewAt = Calendar.current.date(
            byAdding: .day, value: 1, to: Date()  // 明天優先
        )
        return updated
    }
    
    /// 月度喚醒失敗：退回 L2（非 L0）
    static func onMonthlyWakeFail(item: CorpusItem) -> CorpusItem {
        var updated = item
        updated.reviewLevel = .L2
        updated.consecutivePassCount = 0
        updated.lastReviewedAt = Date()
        updated.nextReviewAt = Calendar.current.date(
            byAdding: .day, value: 7, to: Date()
        )
        return updated
    }
    
    /// 取得今日待檢測語料
    static func todaysQueue(from all: [CorpusItem]) -> [CorpusItem] {
        let today = Date()
        return all.filter { item in
            // L0 紅句（昨天標紅 / 新語料 < 7 天）
            let isRedQueue = item.reviewLevel == .L0
            // 到期複習
            let isDueReview = item.nextReviewAt.map { $0 <= today } ?? false
            return isRedQueue || isDueReview
        }
        .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
    }
}
```

### 3.6 題材（Topic）— OTA 遠端配置

```swift
struct TopicCategory: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let topics: [Topic]
}

struct Topic: Codable, Identifiable {
    let id: String
    let title: String
    let triggerQuestion: String
    let targetLang: [TargetLang]
    let tags: [String]
    let weight: Double
}

struct TopicConfig: Codable {
    let version: String
    let season: String
    let categories: [TopicCategory]
    let dailyPicks: [String]       // 今日推薦 topic IDs
    let expiresAt: Date
}
```

### 3.7 音色（Voice）— 用戶配置

```swift
struct VoiceProfile: Codable, Identifiable {
    let id: String
    let name: String
    let gender: VoiceGender
    let accent: VoiceAccent
    let ageRange: VoiceAge
    let sampleURL: URL?
}

enum VoiceGender: String, Codable {
    case male, female
}

enum VoiceAccent: String, Codable {
    case american, british
}

enum VoiceAge: String, Codable {
    case young, mature
}

struct UserVoiceConfig: Codable {
    var primaryVoiceId: String?     // 全局主打音色
    var selectedAt: Date?
}
```

### 3.8 掌握階段（Mastery Stage）— 行為訊號驅動

```swift
enum MasteryStage: Int, Codable, Comparable {
    case allRed = 0             // 全紅期
    case recall20 = 1           // Recall 20-30%
    case clinking = 2           // 靈光乍現
    case basicConversation = 3  // 基礎對話
    case genuinelyConversational = 4  // 真實流利
    
    static func < (lhs: MasteryStage, rhs: MasteryStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// 根據用戶行為訊號判定當前階段
    static func evaluate(
        passRate: Double,           // 整體紅→綠轉換率
        clinkingReports: Int,       // 靈光乍現回報次數
        canBasicConversation: Bool  // 能否用句型簡單對話
    ) -> MasteryStage {
        if canBasicConversation { return .genuinelyConversational }
        if clinkingReports >= 1 { return .clinking }
        if passRate >= 0.2 { return .recall20 }
        return .allRed
    }
}
```

---

## 四、模組邊界與介面（Protocols）

> Domain 層定義 protocol，Infrastructure 層提供實作。所有依賴透過 protocol 注入，支援 mock 測試。

### 4.1 外部服務介面

```swift
// MARK: - TTS 服務
protocol TTSProvider {
    func generate(
        text: String,
        voiceId: String,
        emotion: EmotionTag,
        lang: TargetLang
    ) async throws -> URL  // 回傳本地音檔路徑
    
    func getVoiceLibrary(lang: TargetLang) async throws -> [VoiceProfile]
}

// MARK: - 語音識別服務
protocol SpeechRecognitionService {
    func startRecognition(language: String) -> AsyncThrowingStream<String, Error>
    func stopRecognition()
    var isAvailable: Bool { get }
}

// MARK: - AI 翻譯服務
protocol TranslationService {
    /// 翻譯 + 雙模型交叉驗證
    func translate(
        text: String,
        from source: String,
        to target: TargetLang
    ) async throws -> TranslationResult
    
    /// 自動場景分類
    func classifyScene(text: String) async throws -> SceneCategory
}

struct TranslationResult {
    let translatedText: String
    let naturalScore: Double       // 自然度 1-10
    let needsManualReview: Bool    // < 8 分需人工確認
    let suggestedEmotion: EmotionTag
}

// MARK: - 推播服務
protocol NotificationService {
    func schedule(_ notification: ScheduledNotification) async throws
    func cancel(id: String) async throws
    func cancelAll() async throws
    func requestPermission() async throws -> Bool
}

// MARK: - 音訊播放服務
protocol AudioPlayerService {
    func play(url: URL) async throws
    func pause()
    func resume()
    func next()
    func previous()
    var isPlaying: Bool { get }
    var currentPlaybackPosition: Double { get }
    var playbackEvents: AsyncStream<PlaybackEvent> { get }
}

enum PlaybackEvent {
    case started
    case paused
    case completed
    case progress(Double)  // 0.0 - 1.0
}

// MARK: - 題材配置服務
protocol TopicRepository {
    func fetchConfig() async throws -> TopicConfig
    func getCachedConfig() -> TopicConfig?
}

// MARK: - 語料倉庫
protocol CorpusRepository {
    func save(_ item: CorpusItem) async throws
    func getAll() async throws -> [CorpusItem]
    func getById(_ id: UUID) async throws -> CorpusItem?
    func delete(_ id: UUID) async throws
    func getTodayQueue() async throws -> [CorpusItem]
    func getByReviewLevel(_ level: ReviewLevel) async throws -> [CorpusItem]
    func getMasteredPool() async throws -> [CorpusItem]
}

// MARK: - 寵物倉庫
protocol PetRepository {
    func getPet() async throws -> Pet?
    func savePet(_ pet: Pet) async throws
    func applyXPEvent(_ event: XPEvent) async throws -> Pet
}
```

### 4.2 Domain 層 Use Cases（核心用例）

```swift
// MARK: - 語料管理
protocol AddCorpusUseCase {
    func execute(userTextZH: String, sourceTopicId: String?) async throws -> CorpusItem
}
// 流程：接收中文 → 調 TranslationService 翻譯+分類 → 調 TTSProvider 生成音檔 → 存入 Repository

// MARK: - 檢測
protocol QuizUseCase {
    func getTodayQueue() async throws -> [CorpusItem]
    func submitResult(corpusItemId: UUID, passed: Bool) async throws -> QuizResult
}

struct QuizResult {
    let item: CorpusItem            // 更新後的語料
    let xpEvent: XPEvent            // 觸發的 XP 事件
    let petUpdate: Pet              // 更新後的寵物狀態
    let levelChanged: Bool          // 級別是否變更
}

// MARK: - 寵物狀態管理
protocol PetStatusUseCase {
    func getCurrentPet() async throws -> Pet
    func applyDecay() async throws -> Pet        // 定時衰減（24h/12h）
    func checkEvolution() async throws -> Pet?   // 檢查是否達到進化門檻
    func getDailyStatus() async throws -> PetDailySummary
}

struct PetDailySummary {
    let pet: Pet
    let todayXPEarned: Int
    let todayEvents: [XPEvent]
    let formEvolutionTriggered: Bool
    let dangerWarning: Bool
}

// MARK: - 盲聽播放器
protocol BlindListenUseCase {
    func startSession(corpusItemIds: [UUID]) async throws
    func recordListen(corpusItemId: UUID, count: Int) async throws -> XPEvent?
    func recordPrediction(corpusItemId: UUID, success: Bool) async throws -> XPEvent?
}

// MARK: - 掌握度評估
protocol MasteryEvaluator {
    func currentStage() async throws -> MasteryStage
    func recordClingingReport(corpusItemId: UUID) async throws
    func checkBasicConversationAbility() async throws -> Bool
}

// MARK: - 音色管理
protocol VoiceConfigUseCase {
    func getAvailableVoices(lang: TargetLang) async throws -> [VoiceProfile]
    func setPrimaryVoice(_ voiceId: String) async throws
    func getPrimaryVoice() async throws -> VoiceProfile?
    func generateSample(text: String, voiceId: String) async throws -> URL
}
```

---

## 五、寵物系統：四維度與練習行為綁定

### 5.1 四個維度各自的角色

| 維度 | 角色 | 衰減 | 回答的問題 |
|------|------|------|-----------|
| **Hunger（飽食）** | 長期養分指標 | 每 24h -15 | 「你今天餵它了嗎？」 |
| **Mood（心情）** | 即時情緒指標 | 每 12h -10 | 「你練得好不好？」 |
| **Health（健康）** | 生命力防線 | 雙低持續 24h 才扣 -8/天 | 「你是不是真的要放棄了？」 |
| **Bond（親密度）** | 長期羈絆（隱藏） | 平時不扣，僅沉睡時重置 | 「你們在一起多久了？」 |

### 5.2 練習行為 → 四維度影響總表

| 練習行為 | XP | Hunger | Mood | Health | Bond |
|---------|-----|--------|------|--------|------|
| 打開 App（每日首次）| +1 | — | +2 | — | — |
| 完成夜間預習 | +8 | +5 | +3 | — | — |
| 盲聽 1 遍 | +2 | +1 | — | — | — |
| **盲聽預測成功** | **+20** | +3 | +8 | — | +1 |
| 跟讀 1 遍 | +5 | +3 | +2 | — | — |
| **檢測答對 ✅** | **+15** | +10 | +5 | — | — |
| **檢測答錯 🔴** | **+3** | — | 不扣 | — | — |
| 完成 Daily Win | +12 | — | +15 | — | +1 |
| **靈光乍現** | **+25** | — | +20 | — | +2 |
| 語料產出 | +6 | +3 | +2 | — | — |
| Streak 達標 | +5/天 | — | — | — | +0.5/天 |
| 24h 無學習 | — | -15 | -10 | 視雙低 | — |
| 完成急救任務 | +30 | — | +20 | +40 | — |

### 5.3 四維度 → 寵物整體狀態判定

```
判定邏輯（依序檢查）：

1. Health ≤ 15  →  🔴 危險（進入 72h 緩衝期）
2. Health ≤ 30 或 (Hunger ≤ 20 且 Mood ≤ 30 持續 24h)  →  🟠 生病
3. Hunger ≤ 30 或 Mood ≤ 40  →  🟡 低落
4. Health > 60 且 Hunger > 40  →  🟢 健康
5. 否則  →  🟡 低落
```

### 5.4 衰減 Pipeline（後台定時任務）

```
┌─────────────── 每 12 小時 ──────────────┐
│ Mood -= 10（情緒波動自然衰減）            │
└──────────────────────────────────────────┘
┌─────────────── 每 24 小時 ──────────────┐
│ Hunger -= 15（自然飢餓）                 │
│                                          │
│ if Hunger ≤ 20 && Mood ≤ 30:             │
│     Health -= 8（生命力下降）             │
│                                          │
│ if Health ≤ 15:                           │
│     進入危險狀態，啟動 72h 緩衝倒數       │
│                                          │
│ if 緩衝期結束 && 未完成急救任務:           │
│     → 💤 沉睡                            │
└──────────────────────────────────────────┘
```

### 5.5 XP → 形態進化

| 進化 | 累積 XP 門檻 | 觸發行為 |
|------|-------------|---------|
| 蛋 → 幼體 | 50 | 首次檢測 + 幾次練習 |
| 幼體 → 成長期 | 300 | 約連續 3 天認真練習 |
| 成長期 → 成熟期 | 1000 | 約 Week 3-4 |
| 成熟期 → 傳說型 | 3000 | 約 Week 6+ |

**每日 XP 上限**：200 XP/天（靈光乍現 +25 不受限）

---

## 六、里程碑交付範圍（M0–M3）

### M0：核心驗證（寵物 + 檢測表）

**目標**：驗證「寵物 + 檢測表」能否降低 Week 1 放棄率。

| 模組 | 具體交付 | 涉及層 |
|------|---------|--------|
| 寵物島首頁 | 寵物 2D 顯示（蛋/幼體/成長期）+ 四狀態條 + 今日任務卡片 | Presentation + Domain |
| 檢測表（求生版） | 中→目標語言遮蔽、點擊揭示、一鍵標記 ✅/🔴、每日 3-5 句 | Presentation + Domain |
| App 自動錯題庫 | 語料入庫即建表、遮蔽、紅綠標記、隔日排程 | Domain + Data |
| 基礎 XP 系統 | quizPass +15 / quizFail +3 / dailyWin +12、推動蛋→幼體 | Domain |
| 種子庫 | 20-30 句預置語料（含預生成音檔）| Data |
| 基礎寵物狀態機 | Hunger/Mood/Health + 日常行為（簡化版）| Domain |
| 基礎形態 | 蛋 → 幼體 → 成長期（3 階）| Domain + Presentation |
| Daily Win | 每日錄 1 句最順的，錄音存檔 | Presentation + Infrastructure |
| Onboarding | 命名寵物 + 選目標語言 + 挑種子句 + 孵化儀式 | Presentation |

**不做的**：語音輸入、AI 翻譯、TTS、盲聽播放器、變形同義句、推播系統。

**M0 驗收標準**：
- 用戶能完成：命名寵物 → 選 3 句種子 → 孵化 → 每天做檢測 → 錄 Daily Win
- 寵物能：孵化、成長、顯示狀態變化
- 資料能：本地持久化、重啟不丟失

### M1：語料迴圈

**目標**：讓用戶能持續產出個人化語料。

| 模組 | 具體交付 |
|------|---------|
| 共鳴題材系統 | 6 分類 + OTA 遠端配置 + 今日精選 + 學習覆蓋度六邊形圖 |
| iOS 語音輸入 | SFSpeechRecognizer 即時轉錄 + 編輯確認流程 |
| AI 翻譯 pipeline | 雙模型交叉驗證 + 自然度評分 + 自動場景分類 |
| 音色選擇 | 6 精選音色試聽 + 全局主打設定 |
| ElevenLabs TTS | API 整合 + 音檔快取 + 感情標籤 |
| 夜間加速器 | 文字稿預習 + 生詞標記 + 中英對照 |

**M1 驗收標準**：
- 用戶能完成：選題材 → 語音說中文 → AI 翻譯 → 自動分類 → 生成音檔 → 入庫
- 翻譯品質：雙模型評分 ≥ 8 自動入庫，< 8 標記待確認

### M2：完整學習迴圈

**目標**：完成盲聽→跟讀→檢測完整迴圈 + 微型輸出挑戰。

| 模組 | 具體交付 |
|------|---------|
| 死時間盲聽播放器 | 背景播放 + 鎖屏控制 + 耳機按鍵 + 循環清單 + 遍數追蹤 |
| 預測能力偵測 | 第 4-6 遍提示預測 + 記錄成功/失敗 + 高 XP 獎勵 |
| 影子跟讀模式 | 同步歌詞顯示 + 順序鐵律（盲聽 3 遍才解鎖）+ 錄音比對 |
| 微型輸出挑戰 | Week 2 解鎖：選 1 句過關句對 AI 說 → pattern matching 回應 |
| Smart Excel System | 六級間隔 L0-L5 + Mastered Pool + 月度喚醒 |
| 變形同義句 | Week 4 解鎖 + 連續 3 天過關觸發 + AI 生成 5 句變形 |
| 六週時間線 | 進度視覺化 + 行為訊號階段判定 + 功能解鎖節奏 |

**M2 驗收標準**：
- 完整學習迴圈：預習 → 盲聽 → 預測 → 跟讀 → 檢測 → Daily Win
- 背景播放穩定、鎖屏控制可用、耳機按鍵響應
- Smart Excel 級別正確升降

### M3：寵物深化 + 數據分析

**目標**：完整寵物生命週期 + 數據驅動優化。

| 模組 | 具體交付 |
|------|---------|
| 完整行為規範 | 全部行為表 + 變動比率增強 + 寵物學說話 |
| 完整 XP 系統 | 靈光乍現 +25、預測成功 +20、急救 +30、全部進化門檻 |
| 死亡/重生 pipeline | 低落 → 生病 → 危險 → 沉睡 + 急救任務 + 復活藥 |
| 進化系統 | 成熟期 + 傳說型 + 進化動畫 |
| 推播系統 | 狀態綁定推播 + 疲勞控制（每日上限 3 條）|
| 數據分析 | KPI 埋點 + 掌握階段追蹤 + A/B 測試框架 + 回饋收集 |

---

## 七、關鍵技術決策記錄（ADR）

### ADR-001：使用 SwiftUI 原生而非 React Native

**日期**：2026-06-26
**狀態**：已決定
**背景**：PRD v1.2 原規劃使用 React Native 跨平台框架
**決策**：改用 SwiftUI 原生開發
**理由**：
1. SFSpeechRecognizer 的即時轉錄（partial results）需要低延遲回調，RN bridge 的序列化開銷會劣化體驗
2. 背景播放 + 鎖屏控制 + 耳機按鍵需要完整的 AVAudioSession 控制，RN 第三方庫覆蓋不完整
3. 第一階段只做 iOS，跨平台優勢無法體現
4. 業務邏輯層做成 Swift Package，未來 Android 可用 KMP 共享邏輯
**後果**：Android 版需重寫 UI 層，但核心業務邏輯可共享

### ADR-002：使用 SwiftData 作為持久化方案

**日期**：2026-06-26
**狀態**：已決定
**理由**：Apple 原生 ORM，與 SwiftUI @Query 深度整合，支援 CloudKit 同步，無需第三方依賴

### ADR-003：音色為全局設定而非逐句覆寫

**日期**：2026-06-26
**狀態**：已決定
**理由**：減少 Week 1-2 決策疲勞，用戶專注學習。舊語料保留原音色，切換時間點之後的新語料用新音色

### ADR-004：行為訊號驅動而非時間驅動

**日期**：2026-06-26
**狀態**：已決定
**理由**：XP、寵物形態、掌握階段、功能解鎖全部基於用戶實際行為（答對/預測成功/靈光乍現），而非「過了幾天」。六週時間線僅為約略參考

### ADR-005：Smart Excel 六級間隔

**日期**：2026-06-26
**狀態**：已決定
**理由**：解決語料庫無限增長問題。L0 每天 → L1 3 天 → L2 7 天 → L3 14 天 → L4 30 天 → L5 月度喚醒。卡住回退 L0，月度喚醒失敗退回 L2

### ADR-006：答錯不扣 Mood 且給 +3 XP

**日期**：2026-06-26
**狀態**：已決定
**理由**：保護 Week 1 全紅期用戶的勝任感。「面對摩擦感」本身值得鼓勵，不該被懲罰

---

## 八、Xcode 專案結構建議

```
Selah/
├── SelahApp.swift                     # App 入口
├── App/
│   ├── Navigation/                    # NavigationStack + 路由
│   ├── Theme/                         # 色彩、字體、間距等 Design Tokens
│   └── Components/                    # 共用 UI 元件
│
├── Features/                          # 按功能模組組織
│   ├── Onboarding/                    # 新手引導 + 寵物孵化
│   ├── Island/                        # 寵物島首頁
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── Corpus/                        # 語料庫 + 題材
│   ├── Quiz/                          # 檢測表
│   ├── Listen/                        # 盲聽 + 跟讀播放器
│   ├── Timeline/                      # 六週時間線
│   └── Settings/                      # 設定（音色、推播等）
│
├── Domain/                            # 業務邏輯層（平台無關）
│   ├── Entities/                      # CorpusItem, Pet, XPEvent 等
│   ├── UseCases/                      # AddCorpus, Quiz, PetStatus 等
│   ├── Services/                      # ReviewScheduler, XPCalculator 等
│   └── Protocols/                     # 所有 Repository/Service protocol 定義
│
├── Data/                              # 資料層
│   ├── Models/                        # SwiftData @Model 定義
│   ├── Repositories/                  # Protocol 的 SwiftData 實作
│   ├── Mappers/                       # Entity ↔ SwiftData Model 轉換
│   └── Seed/                          # 種子庫 JSON 資料
│
├── Infrastructure/                    # 基礎設施層
│   ├── TTS/                           # ElevenLabsTTSProvider
│   ├── Speech/                        # SFSpeechRecognitionService
│   ├── Translation/                   # AI TranslationService
│   ├── Audio/                         # AudioPlayerService（背景播放）
│   ├── Notification/                  # NotificationService
│   └── Network/                       # APIClient, Endpoints
│
└── Resources/
    ├── Assets.xcassets                # 圖片、色票
    ├── SeedCorpus.json                # 種子庫語料
    ├── TopicConfig.json               # 本地備份題材配置
    └── LottieAnimations/              # 寵物動畫 JSON
```

---

## 九、外部依賴清單

| 依賴 | 用途 | 引入方式 | 備註 |
|------|------|---------|------|
| **Lottie iOS** | 寵物動畫渲染 | Swift Package Manager | 輕量、跨平台動畫 |
| **Alamofire**（可選）| 網路請求簡化 | SPM | 或用原生 URLSession + async/await |
| **ElevenLabs API** | TTS 語音生成 | REST API | 需 API Key |
| **AI Translation API** | 翻譯 + 審核雙模型 | REST API | 供應商待定（OpenAI/Claude/其他）|

**原則**：盡量用 Apple 原生框架，減少第三方依賴。SwiftData、SFSpeechRecognizer、AVAudioSession、UserNotifications 全部原生。

---

## 十、開放問題與待確認項

以下問題不影響 M0 啟動，但需在對應里程碑前確認：

| # | 問題 | 影響範圍 | 建議確認時機 |
|---|------|---------|-------------|
| 1 | AI 翻譯/審核雙模型的具體供應商選型 | M1 | M0 完成前做技術評估 |
| 2 | ElevenLabs API Key 管理方式（統一帳號 vs 用戶自帶）| M1 | M1 啟動前 |
| 3 | 寵物美術風格（2D Lottie / Spine / 像素風）| M0 | M0 啟動前定稿 |
| 4 | SwiftData vs Core Data 的最終選擇（SwiftData iOS 17+ only）| M0 | 確認最低支援 iOS 版本後 |
| 5 | 付費模型（訂閱制 / 一次性 / ElevenLabs 成本轉嫁）| M2+ | M1 後依成本結構 |
| 6 | 最低支援 iOS 版本 | M0 | M0 啟動前 |
| 7 | CloudKit 同步是否 M0 就需要 | M0 | 視多裝置需求 |
| 8 | 隱私政策與語音資料流向（Apple 伺服器）| M0 上線前 | 法務確認 |

---

> **本文檔版本**：v1.0 | **日期**：2026-06-26
> **下一步**：用戶確認後，更新 PRD 和藍圖反映 Selah 命名 + SwiftUI 技術棧決策，然後進入 M0 User Story 拆解。
