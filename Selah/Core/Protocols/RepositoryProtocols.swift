import Foundation

// MARK: - Data Repository Protocols

/// Repository for Sentence CRUD operations.
protocol SentenceRepository {
    func save(_ sentence: Sentence) async throws
    func fetch(id: UUID) async throws -> Sentence?
    func fetchAll(category: SentenceCategory?, masteryState: ReviewStateValue?) async throws -> [Sentence]
    func fetchDueForPractice(limit: Int) async throws -> [Sentence]
    func fetchSuitableForListen(limit: Int) async throws -> [Sentence]
    func fetchSuitableForPreview(limit: Int) async throws -> [Sentence]
    func fetchCreatedToday() async throws -> [Sentence]
    func count() async throws -> Int
    func delete(_ sentence: Sentence) async throws
}

/// Repository for VocabItem CRUD operations.
protocol VocabRepository {
    func save(_ item: VocabItem) async throws
    func fetch(id: UUID) async throws -> VocabItem?
    func fetchAll(for sentenceID: UUID) async throws -> [VocabItem]
    func fetchByHelpState(_ state: VocabHelpState) async throws -> [VocabItem]
    func fetchActiveHelp() async throws -> [VocabItem]
    func count() async throws -> Int
    func delete(_ item: VocabItem) async throws
}

/// Repository for AudioAsset operations.
protocol AudioAssetRepository {
    func save(_ asset: AudioAsset) async throws
    func fetch(id: UUID) async throws -> AudioAsset?
    func fetchAll(for sentenceID: UUID) async throws -> [AudioAsset]
    func fetchByStatus(_ status: AudioGenerationStatus) async throws -> [AudioAsset]
    func delete(_ asset: AudioAsset) async throws
}

/// Repository for GenerationJob operations.
protocol GenerationJobRepository {
    func save(_ job: GenerationJob) async throws
    func fetch(id: UUID) async throws -> GenerationJob?
    func fetchPending(retryable: Bool, now: Date) async throws -> [GenerationJob]
    func recoverInterruptedJobs() async throws
    func fetchAll(for sentenceID: UUID) async throws -> [GenerationJob]
    func delete(_ job: GenerationJob) async throws
    func cancelAll(for sentenceID: UUID) async throws
}

/// Repository for UserPreference (single-record).
protocol PreferenceRepository {
    func get() async throws -> UserPreference
    func save(_ preference: UserPreference) async throws
}

/// Repository for LearningEvent (append-only log).
protocol LearningEventRepository {
    func save(_ event: LearningEvent) async throws
    func fetchAll(for sentenceID: UUID) async throws -> [LearningEvent]
    func fetchRecent(limit: Int) async throws -> [LearningEvent]
    func fetchRecentByType(_ type: LearningEventType, limit: Int) async throws -> [LearningEvent]
}

/// Repository for SpriteMemory operations.
protocol SpriteMemoryRepository {
    func save(_ memory: SpriteMemory) async throws
    func fetchAll(for companionID: UUID) async throws -> [SpriteMemory]
    func fetchByKey(_ key: String, companionID: UUID) async throws -> SpriteMemory?
    func unlock(key: String, companionID: UUID) async throws
}

/// API client for backend communication.
protocol SelahAPIClientProtocol {
    func generateSentence(
        sourceText: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> GeneratedSentenceResult

    func generateAudio(
        sentenceID: UUID,
        targetText: String,
        voiceProfile: VoiceProfile,
        reason: AudioGenerationReason
    ) async throws -> GeneratedAudioResult

    func fetchBootstrap() async throws -> BootstrapConfig
}

/// Bootstrap configuration from backend.
struct BootstrapConfig: Codable {
    let sourceLanguages: [String]
    let targetLanguages: [String]
    let defaultVoiceProfile: String
    let voiceProfiles: [VoiceProfileConfig]
    let seedSentencePackVersion: String
    let promptVersion: String
    let featureFlags: [String: Bool]
}

struct VoiceProfileConfig: Codable, Identifiable {
    let id: String
    let label: String
    let description: String
}
