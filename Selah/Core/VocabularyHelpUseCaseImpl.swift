import Foundation

/// Vocabulary help use case.
/// Manages the lifecycle of vocabulary items: when to show help,
/// when to hide, when to promote to familiar/owned.
///
/// Rules (from v8 unified design spec §8):
/// - System suggests 1-2 high-value words per sentence
/// - User may manually add other words
/// - Help fades when user appears comfortable
/// - Help returns when user starts struggling
actor VocabularyHelpUseCaseImpl {

    private let vocabRepo: VocabRepository
    private let learningEventRepo: LearningEventRepository

    init(vocabRepo: VocabRepository, learningEventRepo: LearningEventRepository) {
        self.vocabRepo = vocabRepo
        self.learningEventRepo = learningEventRepo
    }

    /// Create vocabulary items from generated candidates.
    func createFromCandidates(
        sentenceID: UUID,
        candidates: [VocabCandidate]
    ) async throws -> [VocabItem] {
        var items: [VocabItem] = []

        for candidate in candidates {
            let item = VocabItem(
                sentenceID: sentenceID,
                surfaceText: candidate.surfaceText,
                meaningInContext: candidate.meaningInContext,
                helpState: candidate.suggestedHelpState,
                manuallyAdded: false
            )
            try await vocabRepo.save(item)
            items.append(item)

            let event = LearningEvent.vocabAdded(sentenceID, word: candidate.surfaceText)
            try await learningEventRepo.save(event)
        }

        return items
    }

    /// User manually adds a word from the sentence.
    func addManualWord(
        sentenceID: UUID,
        surfaceText: String,
        meaningInContext: String
    ) async throws -> VocabItem {
        let item = VocabItem(
            sentenceID: sentenceID,
            surfaceText: surfaceText,
            meaningInContext: meaningInContext,
            helpState: .new,
            manuallyAdded: true
        )
        try await vocabRepo.save(item)

        let event = LearningEvent.vocabAdded(sentenceID, word: surfaceText)
        try await learningEventRepo.save(event)

        return item
    }

    /// Mark a word as encountered (user saw it in deconstruction or quiz).
    func markEncounter(vocabID: UUID, success: Bool) async throws {
        guard let item = try await vocabRepo.fetch(id: vocabID) else { return }
        item.markEncounter(success: success)
        try await vocabRepo.save(item)
    }

    /// Mark a word as naturally used by the user in a new sentence.
    func markUsed(vocabID: UUID) async throws {
        guard let item = try await vocabRepo.fetch(id: vocabID) else { return }
        item.markUsed()
        try await vocabRepo.save(item)
    }

    /// User re-adds a word to active focus.
    func reAddToFocus(vocabID: UUID) async throws {
        guard let item = try await vocabRepo.fetch(id: vocabID) else { return }
        item.reAddToFocus()
        try await vocabRepo.save(item)
    }

    /// Get words that should show help in deconstruction.
    func getActiveHelpWords(for sentenceID: UUID) async throws -> [VocabItem] {
        let items = try await vocabRepo.fetchAll(for: sentenceID)
        return items.filter { $0.activeHelpVisible }
    }
}
