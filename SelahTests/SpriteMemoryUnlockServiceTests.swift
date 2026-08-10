import XCTest
import SwiftData
@testable import Selah

@MainActor
final class SpriteMemoryUnlockServiceTests: XCTestCase {
    func testEnsurePresetsBackfillsOnceWithoutDuplicates() throws {
        let schema = Schema([SpriteMemory.self, LearningEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let service = SpriteMemoryUnlockService(modelContext: context)
        let companionID = UUID()

        try service.ensurePresets(for: companionID)
        try service.ensurePresets(for: companionID)

        let memories = try context.fetch(FetchDescriptor<SpriteMemory>())
        XCTAssertEqual(memories.count, SpriteMemoryPresets.all(for: companionID).count)
        XCTAssertEqual(Set(memories.map(\.memoryKey)).count, memories.count)
    }

    func testUnlocksMatchingTriggerAndRecordsOneIdempotentEvent() throws {
        let schema = Schema([SpriteMemory.self, LearningEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let companionID = UUID()
        let memory = SpriteMemory(
            companionID: companionID,
            memoryKey: "first_listen",
            title: "第一次聆聽",
            descriptionText: "完成第一句",
            icon: "耳朵",
            category: .heard
        )
        context.insert(memory)
        try context.save()
        let service = SpriteMemoryUnlockService(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(try service.unlock(for: .listenCompleted(count: 1), companionID: companionID, now: now))
        XCTAssertFalse(try service.unlock(for: .listenCompleted(count: 1), companionID: companionID, now: now))

        XCTAssertTrue(memory.unlocked)
        XCTAssertEqual(memory.unlockedAt, now)
        let events = try context.fetch(FetchDescriptor<LearningEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .memoryUnlocked)
        XCTAssertEqual(events.first?.metadataJSON, "{\"memory_key\":\"first_listen\"}")
    }
}
