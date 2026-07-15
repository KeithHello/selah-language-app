import Foundation

// MARK: - Audio Generation Result

/// Metadata required to safely download and cache a generated audio file.
struct GeneratedAudioResult: Decodable {
    let status: AudioGenerationStatus
    let voiceProfile: VoiceProfile
    let manifestID: UUID?
    let downloadURL: URL?
    let storagePath: String?
    let sha256: String?
    let byteSize: Int64
    let localFilePath: String?
    let durationMs: Int
    let cacheHit: Bool
    let errorCode: String?

    var isReady: Bool {
        status == .ready && (downloadURL != nil || localFilePath != nil)
    }

    enum CodingKeys: String, CodingKey {
        case status
        case voiceProfile = "voiceProfile"
        case manifestID = "manifestId"
        case downloadURL = "downloadUrl"
        case storagePath = "storagePath"
        case sha256
        case byteSize = "byteSize"
        case localFilePath = "localFilePath"
        case durationMs = "durationMs"
        case cacheHit = "cacheHit"
        case errorCode = "errorCode"
    }

    init(
        status: AudioGenerationStatus,
        voiceProfile: VoiceProfile,
        manifestID: UUID? = nil,
        downloadURL: URL? = nil,
        storagePath: String? = nil,
        sha256: String? = nil,
        byteSize: Int64 = 0,
        localFilePath: String? = nil,
        durationMs: Int = 0,
        cacheHit: Bool = false,
        errorCode: String? = nil
    ) {
        self.status = status
        self.voiceProfile = voiceProfile
        self.manifestID = manifestID
        self.downloadURL = downloadURL
        self.storagePath = storagePath
        self.sha256 = sha256
        self.byteSize = byteSize
        self.localFilePath = localFilePath
        self.durationMs = durationMs
        self.cacheHit = cacheHit
        self.errorCode = errorCode
    }
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
