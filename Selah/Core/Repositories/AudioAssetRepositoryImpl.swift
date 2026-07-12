import Foundation
import SwiftData

/// SwiftData-backed AudioAsset repository.
@MainActor
final class AudioAssetRepositoryImpl: AudioAssetRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ asset: AudioAsset) async throws {
        if asset.modelContext == nil {
            modelContext.insert(asset)
        }
        try modelContext.save()
    }

    func fetch(id: UUID) async throws -> AudioAsset? {
        let descriptor = FetchDescriptor<AudioAsset>(
            predicate: #Predicate<AudioAsset> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchAll(for sentenceID: UUID) async throws -> [AudioAsset] {
        let descriptor = FetchDescriptor<AudioAsset>(
            predicate: #Predicate<AudioAsset> { $0.sentenceID == sentenceID },
            sortBy: [SortDescriptor(\AudioAsset.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByStatus(_ status: AudioGenerationStatus) async throws -> [AudioAsset] {
        let statusRaw = status.rawValue
        let descriptor = FetchDescriptor<AudioAsset>(
            predicate: #Predicate<AudioAsset> { $0.generationStatusRaw == statusRaw }
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ asset: AudioAsset) async throws {
        modelContext.delete(asset)
        try modelContext.save()
    }
}
