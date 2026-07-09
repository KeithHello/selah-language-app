import Foundation
import SwiftData

/// Append-only learning event log for recommendation engine,
/// sprite memories, analytics, and debugging.
/// Never includes raw sentence text.
@Model
final class LearningEvent {
    @Attribute(.unique) var id: UUID

    var sentenceID: UUID?
    var eventTypeRaw: String           // LearningEventType raw value
    var metadataJSON: String           // event-specific data
    var happenedAt: Date

    // MARK: - Convenience

    var eventType: LearningEventType {
        get { LearningEventType(rawValue: eventTypeRaw) ?? .sentenceCreated }
        set { eventTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sentenceID: UUID? = nil,
        eventType: LearningEventType,
        metadataJSON: String = "{}",
        happenedAt: Date = Date()
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.eventTypeRaw = eventType.rawValue
        self.metadataJSON = metadataJSON
        self.happenedAt = happenedAt
    }

    /// Factory for a sentence created event.
    static func sentenceCreated(_ sentence: Sentence) -> LearningEvent {
        LearningEvent(
            sentenceID: sentence.id,
            eventType: .sentenceCreated,
            metadataJSON: """
            {"category":"\(sentence.categoryRaw)","origin":"\(sentence.originRaw)"}
            """
        )
    }

    /// Factory for a listen completed event.
    static func listenCompleted(_ sentenceID: UUID) -> LearningEvent {
        LearningEvent(
            sentenceID: sentenceID,
            eventType: .listenCompleted
        )
    }

    /// Factory for a practice rated event.
    static func practiceRated(_ sentenceID: UUID, signal: RecallSignal) -> LearningEvent {
        LearningEvent(
            sentenceID: sentenceID,
            eventType: .practiceRated,
            metadataJSON: """
            {"signal":"\(signal.rawValue)"}
            """
        )
    }

    /// Factory for a preview completed event.
    static func previewCompleted() -> LearningEvent {
        LearningEvent(eventType: .previewCompleted)
    }

    /// Factory for a vocab added event.
    static func vocabAdded(_ sentenceID: UUID, word: String) -> LearningEvent {
        LearningEvent(
            sentenceID: sentenceID,
            eventType: .vocabAdded,
            metadataJSON: """
            {"word":"\(word)"}
            """
        )
    }
}
