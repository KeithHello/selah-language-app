import XCTest
import SwiftData
@testable import Selah

@MainActor
final class NightPreviewPersistenceTests: XCTestCase {
    func testMarkPreviewedPersistsTimestampAndOneSessionEvent() async throws {
        let schema = Schema([
            Sentence.self,
            VocabItem.self,
            ReviewState.self,
            AudioAsset.self,
            GenerationJob.self,
            LearningEvent.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let sentence = Sentence(
            sourceText: "今天想早点休息。",
            targetText: "I want to get some rest early tonight.",
            origin: .userRecording
        )
        context.insert(sentence)
        try context.save()

        let scheduler = ReviewSchedulerImpl(
            sentenceRepo: SentenceRepositoryImpl(modelContext: context),
            learningEventRepo: LearningEventRepositoryImpl(modelContext: context)
        )
        let now = Date(timeIntervalSince1970: 2_000)

        try await scheduler.markPreviewed(sentenceIDs: [sentence.id], at: now)

        XCTAssertEqual(sentence.previewedAt, now)
        let events = try context.fetch(FetchDescriptor<LearningEvent>())
        XCTAssertEqual(events.filter { $0.eventType == .previewCompleted }.count, 1)
    }
}
