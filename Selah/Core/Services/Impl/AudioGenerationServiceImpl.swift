import Foundation

/// Real backend implementation of AudioGenerationService.
/// Delegates directly to the Selah API client which calls the Supabase Edge Function.
actor AudioGenerationServiceImpl: AudioGenerationService {

    private let apiClient: SelahAPIClientProtocol

    init(apiClient: SelahAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func generateAudio(
        sentenceID: UUID,
        targetText: String,
        voiceProfile: VoiceProfile,
        reason: AudioGenerationReason
    ) async throws -> GeneratedAudioResult {
        return try await apiClient.generateAudio(
            sentenceID: sentenceID,
            targetText: targetText,
            voiceProfile: voiceProfile,
            reason: reason
        )
    }
}
