import Foundation

// MARK: - Sentence Generation Result

struct GeneratedSentenceResult: Codable {
    let targetText: String
    let category: SentenceCategory?
    let vocabulary: [VocabCandidate]
    let deconstruction: [DeconstructionItem]
    let promptVersion: String
}

struct VocabCandidate: Codable, Equatable {
    let surfaceText: String
    let meaningInContext: String
    let suggestedHelpState: VocabHelpState
}

struct DeconstructionItem: Codable, Equatable {
    let surfaceText: String
    let meaning: String
    let type: DeconstructionType

    enum DeconstructionType: String, Codable {
        case phrase
        case pattern
    }
}

struct SegmentTranslationResult: Codable, Identifiable, Equatable {
    let segmentID: UUID
    let targetText: String
    let category: SentenceCategory?
    let vocabulary: [VocabCandidate]
    let deconstruction: [DeconstructionItem]

    var id: UUID { segmentID }

    enum CodingKeys: String, CodingKey {
        case segmentID = "segmentId"
        case targetText
        case category
        case vocabulary
        case deconstruction
    }
}

// MARK: - Sentence Generation Service

protocol SentenceGenerationService {
    /// Generate English learning material from a Chinese sentence.
    /// Calls the backend `/v1/sentences/generate` endpoint.
    func generateSentence(
        sourceText: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> GeneratedSentenceResult

    func prepareCapture(
        rawTranscript: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage
    ) async throws -> CapturePreparation

    func generateSentenceBatch(
        segments: [CaptureSegmentSuggestion],
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> [SegmentTranslationResult]
}

extension SentenceGenerationService {
    func prepareCapture(
        rawTranscript: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage
    ) async throws -> CapturePreparation {
        throw SelahAPIError.serverError(501, "capture preparation unavailable")
    }

    func generateSentenceBatch(
        segments: [CaptureSegmentSuggestion],
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> [SegmentTranslationResult] {
        throw SelahAPIError.serverError(501, "batch generation unavailable")
    }
}
