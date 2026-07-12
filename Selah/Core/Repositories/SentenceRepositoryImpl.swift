import Foundation
import SwiftData

/// SwiftData-backed Sentence repository.
/// Bridges the protocol-based engine layer to SwiftData persistent storage.
@MainActor
final class SentenceRepositoryImpl: SentenceRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ sentence: Sentence) async throws {
        if sentence.modelContext == nil {
            modelContext.insert(sentence)
        }
        try modelContext.save()
    }

    func fetch(id: UUID) async throws -> Sentence? {
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchAll(category: SentenceCategory?, masteryState: ReviewStateValue?) async throws -> [Sentence] {
        var descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> { !$0.archived },
            sortBy: [SortDescriptor(\Sentence.createdAt, order: .reverse)]
        )

        var sentences = try modelContext.fetch(descriptor)

        if let category {
            sentences = sentences.filter { $0.category == category }
        }

        if let masteryState {
            sentences = sentences.filter { $0.reviewState?.state == masteryState }
        }

        return sentences
    }

    func fetchDueForPractice(limit: Int) async throws -> [Sentence] {
        let now = Date()
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> {
                !$0.archived && $0.reviewState != nil
            },
            sortBy: [SortDescriptor(\Sentence.createdAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)

        return all
            .filter { sentence in
                guard let rs = sentence.reviewState else { return false }
                return rs.isDue && (rs.state == .learning || rs.state == .familiar)
            }
            .sorted { (a, b) in
                guard let aRS = a.reviewState, let bRS = b.reviewState else { return false }
                if aRS.state != bRS.state {
                    return aRS.state == .learning
                }
                return aRS.nextReviewAt < bRS.nextReviewAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func fetchSuitableForListen(limit: Int) async throws -> [Sentence] {
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> {
                !$0.archived && $0.originRaw == "user_recording"
            },
            sortBy: [SortDescriptor(\Sentence.createdAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)

        return all
            .filter { sentence in
                sentence.isPreviewedNotListened
                || (sentence.reviewState?.state == .learning
                    && sentence.reviewState?.lastRecallSignal == .failed)
            }
            .prefix(limit)
            .map { $0 }
    }

    func fetchSuitableForPreview(limit: Int) async throws -> [Sentence] {
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> {
                !$0.archived && $0.originRaw == "user_recording" && $0.previewedAt == nil
            },
            sortBy: [SortDescriptor(\Sentence.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).prefix(limit).map { $0 }
    }

    func fetchCreatedToday() async throws -> [Sentence] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> { $0.createdAt >= startOfDay }
        )
        return try modelContext.fetch(descriptor)
    }

    func count() async throws -> Int {
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> { !$0.archived }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func delete(_ sentence: Sentence) async throws {
        modelContext.delete(sentence)
        try modelContext.save()
    }
}
