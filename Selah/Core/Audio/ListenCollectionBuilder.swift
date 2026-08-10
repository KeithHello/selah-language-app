import Foundation
import SwiftData

/// A sentence eligible for the M2 listening flow.
struct ListenCollectionItem: Identifiable {
    let sentence: Sentence
    let audioAsset: AudioAsset

    var id: UUID { sentence.id }
}

/// Builds a small, intentional listening set from real SwiftData records.
/// Priority: today's new sentence, previewed-but-not-listened, then due learning material.
@MainActor
final class ListenCollectionBuilder {
    private let modelContext: ModelContext
    private let memoryUnlockService: SpriteMemoryUnlockService?
    private let companionID: UUID?

    init(
        modelContext: ModelContext,
        memoryUnlockService: SpriteMemoryUnlockService? = nil,
        companionID: UUID? = nil
    ) {
        self.modelContext = modelContext
        self.memoryUnlockService = memoryUnlockService
        self.companionID = companionID
    }

    func build(limit: Int = 3) throws -> [ListenCollectionItem] {
        let descriptor = FetchDescriptor<Sentence>(
            predicate: #Predicate<Sentence> { !$0.archived },
            sortBy: [SortDescriptor(\Sentence.createdAt, order: .reverse)]
        )
        let sentences = try modelContext.fetch(descriptor)
        let calendar = Calendar.current
        let today = Date()

        let candidates = sentences.compactMap { sentence -> ListenCollectionItem? in
            guard let asset = preferredReadyAsset(for: sentence), asset.localFilePath != nil else {
                return nil
            }
            return ListenCollectionItem(sentence: sentence, audioAsset: asset)
        }

        let sorted = candidates.sorted { lhs, rhs in
            let lhsPriority = priority(for: lhs.sentence, today: today, calendar: calendar)
            let rhsPriority = priority(for: rhs.sentence, today: today, calendar: calendar)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.sentence.createdAt > rhs.sentence.createdAt
        }

        return Array(sorted.prefix(max(0, limit)))
    }

    func markListened(_ item: ListenCollectionItem) throws {
        let isFirstCompletion = item.sentence.listenCompletedAt == nil
        item.sentence.listenCompletedAt = Date()
        item.sentence.reviewState?.markListened()
        item.audioAsset.lastPlayedAt = Date()
        if isFirstCompletion {
            modelContext.insert(LearningEvent.listenCompleted(item.sentence.id))
        }
        try modelContext.save()

        if isFirstCompletion, let memoryUnlockService, let companionID {
            let typeRaw = LearningEventType.listenCompleted.rawValue
            let count = try modelContext.fetchCount(
                FetchDescriptor<LearningEvent>(
                    predicate: #Predicate<LearningEvent> { $0.eventTypeRaw == typeRaw }
                )
            )
            try memoryUnlockService.unlock(
                for: .listenCompleted(count: count),
                companionID: companionID
            )
        }
    }

    private func preferredReadyAsset(for sentence: Sentence) -> AudioAsset? {
        sentence.audioAssets.first { asset in
            asset.generationStatus == .ready && asset.localFilePath != nil
        }
    }

    private func priority(for sentence: Sentence, today: Date, calendar: Calendar) -> Int {
        if calendar.isDate(sentence.createdAt, inSameDayAs: today) { return 0 }
        if sentence.isPreviewedNotListened { return 1 }
        if sentence.reviewState?.isDue == true { return 2 }
        return 3
    }
}
