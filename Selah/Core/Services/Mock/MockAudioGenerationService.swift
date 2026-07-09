import Foundation

/// Mock audio generation service for prototyping.
/// Simulates audio generation with a delay.
actor MockAudioGenerationService: AudioGenerationService {

    private let mockDelay: UInt64 = 2_000_000_000  // 2 seconds

    func generateAudio(
        sentenceID: UUID,
        targetText: String,
        voiceProfile: VoiceProfile,
        reason: AudioGenerationReason
    ) async throws -> GeneratedAudioResult {
        try await Task.sleep(nanoseconds: mockDelay)

        // Simulate successful generation with a mock file path
        return GeneratedAudioResult(
            status: .ready,
            voiceProfile: voiceProfile,
            downloadURL: nil,
            localFilePath: "mock/audio/\(sentenceID.uuidString).mp3",
            durationMs: Int.random(in: 2000...5000)
        )
    }
}
