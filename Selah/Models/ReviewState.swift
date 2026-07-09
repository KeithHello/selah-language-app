import Foundation
import SwiftData

/// Internal review state for a sentence. Never shown to users.
/// Replaces the retired Smart Excel L0-L5 system.
@Model
final class ReviewState {
    @Attribute(.unique) var id: UUID

    var sentenceID: UUID
    var stateRaw: String          // ReviewStateValue raw value
    var nextReviewAt: Date
    var lastRecallSignalRaw: String?  // RecallSignal raw value
    var intervalDays: Int         // current review interval in days
    var lapseCount: Int           // number of consecutive failures
    var updatedAt: Date

    // MARK: - Convenience

    var state: ReviewStateValue {
        get { ReviewStateValue(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }

    var lastRecallSignal: RecallSignal? {
        get {
            guard let raw = lastRecallSignalRaw else { return nil }
            return RecallSignal(rawValue: raw)
        }
        set { lastRecallSignalRaw = newValue?.rawValue }
    }

    var isDue: Bool {
        Date() >= nextReviewAt
    }

    init(
        id: UUID = UUID(),
        sentenceID: UUID,
        state: ReviewStateValue = .new,
        nextReviewAt: Date = Date(),
        intervalDays: Int = 1,
        lapseCount: Int = 0
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.stateRaw = state.rawValue
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
        self.lapseCount = lapseCount
        self.updatedAt = Date()
    }

    /// Apply a recall signal and transition to the next state.
    func applyRecall(_ signal: RecallSignal) {
        let nextState = state.nextState(after: signal)
        let interval = state.nextInterval(after: signal)

        state = nextState
        intervalDays = interval
        lastRecallSignal = signal
        nextReviewAt = Calendar.current.date(
            byAdding: .day,
            value: interval,
            to: Date()
        ) ?? Date().addingTimeInterval(Double(interval) * 86400)

        // Track lapses
        if signal == .failed {
            lapseCount += 1
        } else if signal == .clear {
            lapseCount = 0
        }

        updatedAt = Date()
    }

    /// Mark as listened. Moves from new → learning.
    func markListened() {
        if state == .new {
            state = .learning
            intervalDays = 1
            nextReviewAt = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Date()
            ) ?? Date().addingTimeInterval(86400)
            updatedAt = Date()
        }
    }
}
