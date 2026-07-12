import Foundation
import SwiftData

/// SwiftData-backed VocabItem repository.
@MainActor
final class VocabRepositoryImpl: VocabRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ item: VocabItem) async throws {
        if item.modelContext == nil {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    func fetch(id: UUID) async throws -> VocabItem? {
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate<VocabItem> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchAll(for sentenceID: UUID) async throws -> [VocabItem] {
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate<VocabItem> { $0.sentenceID == sentenceID },
            sortBy: [SortDescriptor(\VocabItem.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByHelpState(_ state: VocabHelpState) async throws -> [VocabItem] {
        let stateRaw = state.rawValue
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate<VocabItem> { $0.helpStateRaw == stateRaw }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchActiveHelp() async throws -> [VocabItem] {
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate<VocabItem> { $0.activeHelpVisible == true }
        )
        return try modelContext.fetch(descriptor)
    }

    func count() async throws -> Int {
        let descriptor = FetchDescriptor<VocabItem>()
        return try modelContext.fetchCount(descriptor)
    }

    func delete(_ item: VocabItem) async throws {
        modelContext.delete(item)
        try modelContext.save()
    }
}
