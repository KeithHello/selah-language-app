import Foundation

// MARK: - Today Recommendation

struct TodayRecommendation {
    let type: TodayRecommendationType
    let reason: String               // user-facing reason text
    let sentenceCount: Int           // how many sentences are ready
    let reasonItems: [ReasonItem]    // 2-3 items for "為什麼是這一步？"

    struct ReasonItem: Identifiable {
        let id: UUID
        let sentencePreview: String  // source sentence or short title
        let nextState: String        // "現在" / "今晚" / "明天"
        let plainReason: String      // e.g. "之前聽過，現在剛好叫回來"
    }
}

// MARK: - Contextual Bridge

struct ContextualBridge {
    let suggestion: BridgeSuggestion

    enum BridgeSuggestion {
        case practice(Int)            // "順手練 N 句"
        case listenMore(Int)          // "再聽一組"
        case previewMore(Int)         // "我還想再看幾句"
        case recordAnother            // "還有一句想說"
        case stop                     // "先到這裡"
    }
}

// MARK: - Recommendation Engine

protocol RecommendationEngine {
    /// Compute the best next action based on local sentence states.
    /// Runs entirely on-device; no backend call required.
    func recommendNextAction(now: Date) async throws -> TodayRecommendation

    /// Build a contextual bridge after completing a learning action.
    func buildContextualBridge(after event: LearningEvent) async throws -> ContextualBridge?
}
