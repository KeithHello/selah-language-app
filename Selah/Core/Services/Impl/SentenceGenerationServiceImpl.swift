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
}
