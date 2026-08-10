import XCTest
import SwiftData
@testable import Selah

@MainActor
final class OnboardingCompletionServiceTests: XCTestCase {
    func testCompletePersistsNamePreferenceAndThreeSeedsIdempotently() throws {
        let schema = Schema([
            Sentence.self,
            VocabItem.self,
            ReviewState.self,
            AudioAsset.self,
            GenerationJob.self,
            Companion.self,
            SpriteMemory.self,
            UserPreference.self,
            LearningEvent.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let companion = Companion(displayName: "語言精靈")
        let preference = UserPreference.default()
        context.insert(companion)
        context.insert(preference)
        for memory in SpriteMemoryPresets.all(for: companion.id) {
            context.insert(memory)
        }
        try context.save()

        let service = OnboardingCompletionService(modelContext: context)
        try service.complete(
            companionName: " 小豆 ",
            selectedSeeds: Array(OnboardingSeedPreset.defaults.prefix(3)),
            companion: companion,
            preference: preference
        )
        try service.complete(
            companionName: "小豆",
            selectedSeeds: Array(OnboardingSeedPreset.defaults.prefix(3)),
            companion: companion,
            preference: preference
        )

        let sentences = try context.fetch(FetchDescriptor<Sentence>())
        XCTAssertEqual(companion.displayName, "小豆")
        XCTAssertTrue(preference.onboardingCompleted)
        XCTAssertEqual(preference.activeCompanionID, companion.id)
        XCTAssertEqual(sentences.count, 3)
        XCTAssertTrue(sentences.allSatisfy { $0.origin == .systemSeed })
        let memories = try context.fetch(FetchDescriptor<SpriteMemory>())
        let unlockedKeys = Set(memories.filter(\.unlocked).map(\.memoryKey))
        XCTAssertEqual(unlockedKeys, Set(["first_name", "first_seed_sentence"]))
        let unlockEvents = try context.fetch(FetchDescriptor<LearningEvent>())
            .filter { $0.eventType == .memoryUnlocked }
        XCTAssertEqual(unlockEvents.count, 2)
    }
}
