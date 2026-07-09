import Foundation
import SwiftData

/// Audio file asset tied to a sentence and voice profile.
/// Stored locally in FileManager; generation status tracked here.
@Model
final class AudioAsset {
    @Attribute(.unique) var id: UUID

    var sentenceID: UUID
    var voiceProfileRaw: String          // VoiceProfile raw value
    var localFilePath: String?           // relative path in Documents/audio/
    var remoteAssetID: String?           // server-side identifier
    var generationStatusRaw: String      // AudioGenerationStatus raw value
    var generationReasonRaw: String      // AudioGenerationReason raw value
    var fileSizeBytes: Int64
    var durationMs: Int
    var createdAt: Date
    var downloadedAt: Date?

    // MARK: - Convenience

    var voiceProfile: VoiceProfile {
        get { VoiceProfile(rawValue: voiceProfileRaw) ?? .gentleNatural }
        set { voiceProfileRaw = newValue.rawValue }
    }

    var generationStatus: AudioGenerationStatus {
        get { AudioGenerationStatus(rawValue: generationStatusRaw) ?? .queued }
        set { generationStatusRaw = newValue.rawValue }
    }

    var generationReason: AudioGenerationReason {
        get { AudioGenerationReason(rawValue: generationReasonRaw) ?? .initialGeneration }
        set { generationReasonRaw = newValue.rawValue }
    }

    var isReady: Bool { generationStatus == .ready }

    init(
        id: UUID = UUID(),
        sentenceID: UUID,
        voiceProfile: VoiceProfile = .gentleNatural,
        generationReason: AudioGenerationReason = .initialGeneration
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.voiceProfileRaw = voiceProfile.rawValue
        self.generationStatusRaw = AudioGenerationStatus.queued.rawValue
        self.generationReasonRaw = generationReason.rawValue
        self.fileSizeBytes = 0
        self.durationMs = 0
        self.createdAt = Date()
    }
}
