import Foundation
import SwiftData

/// User preferences: voice, speed, language, notification settings.
/// Single-record model (enforced at the app level).
@Model
final class UserPreference {
    @Attribute(.unique) var id: UUID

    var sourceLanguageRaw: String      // SourceLanguage raw value
    var targetLanguageRaw: String      // TargetLanguage raw value
    var voiceProfileRaw: String        // VoiceProfile raw value
    var playbackSpeedRaw: Double       // PlaybackSpeed raw value
    var notificationEnabled: Bool
    var notificationTime: String?      // "HH:mm" format
    var activeCompanionID: UUID?
    var onboardingCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Convenience

    var sourceLanguage: SourceLanguage {
        get { SourceLanguage(rawValue: sourceLanguageRaw) ?? .zhHant }
        set { sourceLanguageRaw = newValue.rawValue }
    }

    var targetLanguage: TargetLanguage {
        get { TargetLanguage(rawValue: targetLanguageRaw) ?? .en }
        set { targetLanguageRaw = newValue.rawValue }
    }

    var voiceProfile: VoiceProfile {
        get { VoiceProfile(rawValue: voiceProfileRaw) ?? .gentleNatural }
        set { voiceProfileRaw = newValue.rawValue }
    }

    var playbackSpeed: PlaybackSpeed {
        get { PlaybackSpeed(rawValue: playbackSpeedRaw) ?? .learning }
        set { playbackSpeedRaw = newValue.rawValue }
    }

    static func `default`() -> UserPreference {
        UserPreference()
    }

    init(
        id: UUID = UUID(),
        sourceLanguage: SourceLanguage = .zhHant,
        targetLanguage: TargetLanguage = .en,
        voiceProfile: VoiceProfile = .gentleNatural,
        playbackSpeed: PlaybackSpeed = .learning,
        notificationEnabled: Bool = true,
        notificationTime: String? = "20:00",
        onboardingCompleted: Bool = false
    ) {
        self.id = id
        self.sourceLanguageRaw = sourceLanguage.rawValue
        self.targetLanguageRaw = targetLanguage.rawValue
        self.voiceProfileRaw = voiceProfile.rawValue
        self.playbackSpeedRaw = playbackSpeed.rawValue
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
