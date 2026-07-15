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
    }
}
