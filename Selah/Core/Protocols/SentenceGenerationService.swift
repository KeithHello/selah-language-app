import Foundation

// MARK: - Sentence Generation Result

struct GeneratedSentenceResult: Codable {
    let targetText: String
    let category: SentenceCategory?
    let vocabulary: [VocabCandidate]
    let deconstruction: [DeconstructionItem]
    let promptVersion: String
}

struct VocabCandidate: Codable {
    let surfaceText: String
    let meaningInContext: String
    let suggestedHelpState: VocabHelpState
}

struct DeconstructionItem: Codable {
    let surfaceText: String
    let meaning: String
    let type: DeconstructionType

    enum DeconstructionType: String, Codable {
        case phrase
        case pattern
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
}
