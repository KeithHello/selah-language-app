import Foundation

// MARK: - Audio Generation Result

struct GeneratedAudioResult {
    let status: AudioGenerationStatus
    let voiceProfile: VoiceProfile
    let downloadURL: URL?
    let localFilePath: String?
    let durationMs: Int

    var isReady: Bool { status == .ready }
}

// MARK: - Audio Generation Service

protocol AudioGenerationService {
    /// Generate or regenerate audio for an English sentence.
    /// Calls the backend `/v1/audio/generate` endpoint.
    func generateAudio(
        sentenceID: UUID,
        targetText: String,
        voiceProfile: VoiceProfile,
        reason: AudioGenerationReason
    ) async throws -> GeneratedAudioResult
}
