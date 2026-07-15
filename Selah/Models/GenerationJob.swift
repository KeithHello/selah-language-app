import Foundation
import SwiftData

struct AudioGenerationRetryPayload: Codable, Equatable {
    let targetText: String
    let voiceProfile: VoiceProfile
    let reason: AudioGenerationReason
}

/// Local retry queue entry for AI generation, TTS generation,
/// and manual voice regeneration.
@Model
final class GenerationJob {
    @Attribute(.unique) var id: UUID

    var sentenceID: UUID
    var jobTypeRaw: String              // GenerationJobType raw value
    var statusRaw: String               // GenerationJobStatus raw value
    var retryCount: Int
    var maxRetries: Int
    var lastErrorCode: String?
    var nextRetryAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var payloadJSON: String             // additional context for retry

    // MARK: - Convenience

    var jobType: GenerationJobType {
        get { GenerationJobType(rawValue: jobTypeRaw) ?? .sentenceGeneration }
        set { jobTypeRaw = newValue.rawValue }
    }

    var status: GenerationJobStatus {
        get { GenerationJobStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var isRetryable: Bool {
        status != .completed && retryCount < maxRetries
    }

    /// Exponential backoff: 2^retryCount seconds, max 300s.
    var backoffSeconds: TimeInterval {
        min(pow(2.0, Double(retryCount)), 300)
    }

    init(
        id: UUID = UUID(),
        sentenceID: UUID,
        jobType: GenerationJobType,
        maxRetries: Int = 5,
        payloadJSON: String = "{}"
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.jobTypeRaw = jobType.rawValue
        self.statusRaw = GenerationJobStatus.pending.rawValue
        self.retryCount = 0
        self.maxRetries = maxRetries
        self.payloadJSON = payloadJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    convenience init(
        id: UUID = UUID(),
        sentenceID: UUID,
        jobType: GenerationJobType,
        maxRetries: Int = 5,
        audioPayload: AudioGenerationRetryPayload
    ) throws {
        let data = try JSONEncoder().encode(audioPayload)
        guard let payloadJSON = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                audioPayload,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Audio retry payload could not be encoded as UTF-8 JSON."
                )
            )
        }
        self.init(
            id: id,
            sentenceID: sentenceID,
            jobType: jobType,
            maxRetries: maxRetries,
            payloadJSON: payloadJSON
        )
    }

    func decodeAudioPayload() throws -> AudioGenerationRetryPayload {
        let data = Data(payloadJSON.utf8)
        return try JSONDecoder().decode(AudioGenerationRetryPayload.self, from: data)
    }

    func markInProgress() {
        status = .inProgress
        updatedAt = Date()
    }

    func markCompleted() {
        status = .completed
        updatedAt = Date()
    }

    func markFailed(errorCode: String?) {
        status = .failed
        retryCount += 1
        lastErrorCode = errorCode
        nextRetryAt = Date().addingTimeInterval(backoffSeconds)
        updatedAt = Date()
    }
}
