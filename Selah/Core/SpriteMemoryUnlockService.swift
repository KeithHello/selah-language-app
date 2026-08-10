import Foundation
import SwiftData

@MainActor
final class SpriteMemoryUnlockService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func ensurePresets(for companionID: UUID) throws {
        let existing = try modelContext.fetch(FetchDescriptor<SpriteMemory>())
            .filter { $0.companionID == companionID }
        let existingKeys = Set(existing.map(\.memoryKey))
        for memory in SpriteMemoryPresets.all(for: companionID)
            where !existingKeys.contains(memory.memoryKey) {
            modelContext.insert(memory)
        }
        try modelContext.save()
    }

    @discardableResult
    func unlock(
        for trigger: SpriteMemoryPresets.Trigger,
        companionID: UUID,
        now: Date = Date()
    ) throws -> Bool {
        guard let key = SpriteMemoryPresets.key(for: trigger) else { return false }
        return try unlock(key: key, companionID: companionID, now: now)
    }

    @discardableResult
    func unlock(key: String, companionID: UUID, now: Date = Date()) throws -> Bool {
        let memories = try modelContext.fetch(FetchDescriptor<SpriteMemory>())
        guard let memory = memories.first(where: {
            $0.companionID == companionID && $0.memoryKey == key
        }), !memory.unlocked else {
            return false
        }

        memory.unlocked = true
        memory.unlockedAt = now
        modelContext.insert(
            LearningEvent(
                eventType: .memoryUnlocked,
                metadataJSON: "{\"memory_key\":\"\(key)\"}",
                happenedAt: now
            )
        )
        try modelContext.save()
        return true
    }
}
