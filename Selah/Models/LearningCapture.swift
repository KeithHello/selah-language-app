import Foundation
import SwiftData

enum CaptureDraftStatus: String, Codable {
    case transcriptReady = "transcript_ready"
    case preparing
    case readyForReview = "ready_for_review"
    case translating
    case completed
    case failed
}

enum CaptureSegmentStatus: String, Codable {
    case suggested
    case selected
    case translated
    case failed
}

@Model
final class CaptureDraft {
    @Attribute(.unique) var id: UUID
    var rawTranscript: String
    var normalizedTranscript: String
    var sourceLanguageRaw: String
    var targetLanguageRaw: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var segments: [LearningSegmentDraft]

    var status: CaptureDraftStatus {
        get { CaptureDraftStatus(rawValue: statusRaw) ?? .transcriptReady }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    init(
        id: UUID = UUID(),
        rawTranscript: String,
        normalizedTranscript: String,
        sourceLanguage: SourceLanguage = .zhHant,
        targetLanguage: TargetLanguage = .en,
        status: CaptureDraftStatus = .transcriptReady
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.normalizedTranscript = normalizedTranscript
        self.sourceLanguageRaw = sourceLanguage.rawValue
        self.targetLanguageRaw = targetLanguage.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.segments = []
    }
}

@Model
final class LearningSegmentDraft {
    @Attribute(.unique) var id: UUID
    var captureID: UUID
    var orderIndex: Int
    var originalText: String
    var sourceText: String
    var removedTextJSON: String
    var statusRaw: String
    var selected: Bool
    var translationJSON: String?
    var createdAt: Date
    var updatedAt: Date

    var status: CaptureSegmentStatus {
        get { CaptureSegmentStatus(rawValue: statusRaw) ?? .suggested }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    init(
        id: UUID = UUID(),
        captureID: UUID,
        orderIndex: Int,
        originalText: String,
        sourceText: String,
        removedText: [String] = [],
        selected: Bool = true,
        status: CaptureSegmentStatus = .suggested
    ) {
        self.id = id
        self.captureID = captureID
        self.orderIndex = orderIndex
        self.originalText = originalText
        self.sourceText = sourceText
        self.removedTextJSON = (try? String(
            data: JSONEncoder().encode(removedText),
            encoding: .utf8
        )) ?? "[]"
        self.statusRaw = status.rawValue
        self.selected = selected
        self.translationJSON = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
