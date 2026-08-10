import Foundation

/// On-device review scheduler implementation.
/// Uses the v8 simplified state model: new → learning → familiar → quiet.
actor ReviewSchedulerImpl: ReviewScheduler {

    private let sentenceRepo: SentenceRepository
    private let learningEventRepo: LearningEventRepository

    init(sentenceRepo: SentenceRepository, learningEventRepo: LearningEventRepository) {
        self.sentenceRepo = sentenceRepo
        self.learningEventRepo = learningEventRepo
    }

    func updateAfterListen(sentenceID: UUID, at date: Date) async throws {
        guard let sentence = try await sentenceRepo.fetch(id: sentenceID) else { return }
        guard let reviewState = sentence.reviewState else { return }

        reviewState.markListened()
        sentence.listenCompletedAt = date
        try await sentenceRepo.save(sentence)

        let event = LearningEvent.listenCompleted(sentenceID)
        try await learningEventRepo.save(event)
    }

    func updateAfterPractice(
        sentenceID: UUID,
        signal: RecallSignal,
        at date: Date
    ) async throws {
        guard let sentence = try await sentenceRepo.fetch(id: sentenceID) else { return }
        guard let reviewState = sentence.reviewState else { return }

        reviewState.applyRecall(signal)
        try await sentenceRepo.save(sentence)

        let event = LearningEvent.practiceRated(sentenceID, signal: signal)
        try await learningEventRepo.save(event)
    }

    func dueForPractice(limit: Int) async throws -> [Sentence] {
        let all = try await sentenceRepo.fetchAll(category: nil, masteryState: nil)
        return all
            .filter { sentence in
                guard let rs = sentence.reviewState else { return false }
                return rs.isDue && (rs.state == .learning || rs.state == .familiar)
            }
            .sorted { (a, b) in
                guard let aRS = a.reviewState, let bRS = b.reviewState else { return false }
                // Prefer learning over familiar
                if aRS.state != bRS.state {
                    return aRS.state == .learning
                }
                // Earlier due date first
                return aRS.nextReviewAt < bRS.nextReviewAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func suitableForListen(limit: Int) async throws -> [Sentence] {
        let all = try await sentenceRepo.fetchAll(category: nil, masteryState: nil)
        return all
            .filter { sentence in
                !sentence.archived
                && sentence.origin == .userRecording
                && (sentence.isPreviewedNotListened
                    || (sentence.reviewState?.state == .learning
                        && sentence.reviewState?.lastRecallSignal == .failed))
            }
            .prefix(limit)
            .map { $0 }
    }

    func suitableForPreview(limit: Int) async throws -> [Sentence] {
        let all = try await sentenceRepo.fetchAll(category: nil, masteryState: nil)
        return all
            .filter { sentence in
                !sentence.archived
                && sentence.previewedAt == nil
                && sentence.origin == .userRecording
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func markPreviewed(sentenceIDs: [UUID], at date: Date) async throws {
        guard !sentenceIDs.isEmpty else { return }
        for sentenceID in sentenceIDs {
            guard let sentence = try await sentenceRepo.fetch(id: sentenceID),
                  sentence.previewedAt == nil else { continue }
            sentence.previewedAt = date
            try await sentenceRepo.save(sentence)
        }
        try await learningEventRepo.save(.previewCompleted())
    }

    func isContentPoolLow() async throws -> Bool {
        let count = try await sentenceRepo.count()
        return count < 5
    }

    func hasCreatedSentenceToday() async throws -> Bool {
        let todaySentences = try await sentenceRepo.fetchCreatedToday()
        return !todaySentences.isEmpty
    }
}
