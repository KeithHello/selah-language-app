import Foundation

/// Real backend implementation of SentenceGenerationService.
/// Delegates directly to the Selah API client which calls the Supabase Edge Function.
actor SentenceGenerationServiceImpl: SentenceGenerationService {

    private let apiClient: SelahAPIClientProtocol

    init(apiClient: SelahAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func generateSentence(
        sourceText: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> GeneratedSentenceResult {
        return try await apiClient.generateSentence(
            sourceText: sourceText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            categoryHint: categoryHint
        )
    }

    func prepareCapture(
        rawTranscript: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage
    ) async throws -> CapturePreparation {
        try await apiClient.prepareCapture(
            rawTranscript: rawTranscript,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    func generateSentenceBatch(
        segments: [CaptureSegmentSuggestion],
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> [SegmentTranslationResult] {
        try await apiClient.generateSentenceBatch(
            segments: segments,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            categoryHint: categoryHint
        )
    }
}
