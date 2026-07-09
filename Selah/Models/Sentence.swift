import Foundation
import SwiftData

/// The core unit of learning. Every preview, listen, practice, vocab
/// item, and audio asset belongs to a sentence.
@Model
final class Sentence {
    @Attribute(.unique) var id: UUID

    // Source text
    var sourceText: String           // Traditional Chinese (the user's sentence)
    var targetText: String           // Natural English translation

    // Category
    var categoryRaw: String          // SentenceCategory raw value

    // Origin
    var originRaw: String            // SentenceOrigin raw value

    // Audio reference (local cache)
    @Relationship(deleteRule: .cascade) var audioAssets: [AudioAsset]

    // Deconstruction data (stored as JSON string in SwiftData)
    var deconstructionJSON: String
    var vocabCandidatesJSON: String

    // Review scheduling (backed by a separate ReviewState)
    @Relationship(deleteRule: .cascade) var reviewState: ReviewState?

    // Vocabulary items
    @Relationship(deleteRule: .cascade) var vocabItems: [VocabItem]

    // Learning events
    @Relationship(deleteRule: .cascade) var learningEvents: [LearningEvent]

    // Generation jobs
    @Relationship(deleteRule: .cascade) var generationJobs: [GenerationJob]

    // Timestamps
    var createdAt: Date
    var archived: Bool

    // Preview / listen / practice timeline
    var previewedAt: Date?
    var listenCompletedAt: Date?

    // Computed: eligible for Practice only after Listen is completed
    var isPracticeReady: Bool {
        listenCompletedAt != nil && !archived
    }

    var isPreviewedNotListened: Bool {
        previewedAt != nil && listenCompletedAt == nil && !archived
    }

    var sourceLanguage: String { "zh-Hant" }
    var targetLanguage: String { "en" }

    // MARK: - Convenience

    var category: SentenceCategory {
        get { SentenceCategory(rawValue: categoryRaw) ?? .dailyLife }
        set { categoryRaw = newValue.rawValue }
    }

    var origin: SentenceOrigin {
        get { SentenceOrigin(rawValue: originRaw) ?? .userRecording }
        set { originRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sourceText: String,
        targetText: String,
        category: SentenceCategory = .dailyLife,
        origin: SentenceOrigin = .userRecording,
        deconstructionJSON: String = "[]",
        vocabCandidatesJSON: String = "[]",
        createdAt: Date = Date(),
        archived: Bool = false
    ) {
        self.id = id
        self.sourceText = sourceText
        self.targetText = targetText
        self.categoryRaw = category.rawValue
        self.originRaw = origin.rawValue
        self.deconstructionJSON = deconstructionJSON
        self.vocabCandidatesJSON = vocabCandidatesJSON
        self.createdAt = createdAt
        self.archived = archived
        self.audioAssets = []
        self.vocabItems = []
        self.learningEvents = []
        self.generationJobs = []
    }
}
