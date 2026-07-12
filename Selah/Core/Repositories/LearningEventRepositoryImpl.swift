import Foundation
import SwiftData

/// SwiftData-backed LearningEvent repository.
/// Events are append-only: no update or delete operations.
@MainActor
final class LearningEventRepositoryImpl: LearningEventRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ event: LearningEvent) async throws {
        if event.modelContext == nil {
            modelContext.insert(event)
        }
        try modelContext.save()
    }

    func fetchAll(for sentenceID: UUID) async throws -> [LearningEvent] {
        let descriptor = FetchDescriptor<LearningEvent>(
            predicate: #Predicate<LearningEvent> { $0.sentenceID == sentenceID },
            sortBy: [SortDescriptor(\LearningEvent.happenedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchRecent(limit: Int) async throws -> [LearningEvent] {
        var descriptor = FetchDescriptor<LearningEvent>(
            sortBy: [SortDescriptor(\LearningEvent.happenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func fetchRecentByType(_ type: LearningEventType, limit: Int) async throws -> [LearningEvent] {
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<LearningEvent>(
            predicate: #Predicate<LearningEvent> { $0.eventTypeRaw == typeRaw },
            sortBy: [SortDescriptor(\LearningEvent.happenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
}
