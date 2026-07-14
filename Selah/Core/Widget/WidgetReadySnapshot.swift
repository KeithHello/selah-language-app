import Foundation

/// Privacy-safe data contract for a future WidgetKit extension.
struct WidgetReadySnapshot: Codable, Equatable, Sendable {
    static let maxActionLength = 48
    static let maxCompanionNameLength = 24

    let todaySentenceCount: Int
    let listenedCount: Int
    let dueReviewCount: Int
    let recommendation: String
    let companionDisplayName: String
    let generatedAt: Date

    init(
        todaySentenceCount: Int,
        listenedCount: Int,
        dueReviewCount: Int,
        recommendation: String,
        companionDisplayName: String,
        generatedAt: Date = Date()
    ) {
        self.todaySentenceCount = max(0, todaySentenceCount)
        self.listenedCount = max(0, listenedCount)
        self.dueReviewCount = max(0, dueReviewCount)
        self.recommendation = Self.bounded(recommendation, limit: Self.maxActionLength)
        self.companionDisplayName = Self.bounded(companionDisplayName, limit: Self.maxCompanionNameLength)
        self.generatedAt = generatedAt
    }

    private static func bounded(_ text: String, limit: Int) -> String {
        let characters = Array(text)
        guard characters.count > limit else { return text }
        return String(characters.prefix(max(0, limit - 1))) + "…"
    }
}

struct WidgetReadyCounts: Sendable {
    let todaySentenceCount: Int
    let listenedCount: Int
    let dueReviewCount: Int
}

/// Builds a widget contract without exposing personal sentence text.
struct WidgetReadySnapshotBuilder: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func build(
        counts: WidgetReadyCounts,
        recommendation: String,
        companionDisplayName: String,
        generatedAt: Date = Date()
    ) -> WidgetReadySnapshot {
        WidgetReadySnapshot(
            todaySentenceCount: counts.todaySentenceCount,
            listenedCount: counts.listenedCount,
            dueReviewCount: counts.dueReviewCount,
            recommendation: recommendation,
            companionDisplayName: companionDisplayName,
            generatedAt: generatedAt
        )
    }
}
