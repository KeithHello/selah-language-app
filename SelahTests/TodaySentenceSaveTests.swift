import XCTest
import SwiftData
@testable import Selah

final class TodaySentenceSaveTests: XCTestCase {
    @MainActor
    func testSavePersistsVocabularyCandidatesAsLearningItems() async throws {
        let schema = Schema([
            Sentence.self,
            VocabItem.self,
            ReviewState.self,
            AudioAsset.self,
            GenerationJob.self,
            SpriteMemory.self,
            LearningEvent.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let companionID = UUID()
        let firstSentenceMemory = SpriteMemory(
            companionID: companionID,
            memoryKey: "first_own_sentence",
            title: "第一次自己的句子",
            descriptionText: "完成第一句",
            icon: "星星",
            category: .started
        )
        context.insert(firstSentenceMemory)
        let vocabularyHelp = VocabularyHelpUseCaseImpl(
            vocabRepo: VocabRepositoryImpl(modelContext: context),
            learningEventRepo: LearningEventRepositoryImpl(modelContext: context)
        )
        let viewModel = TodaySentenceViewModel(
            speechService: MockSpeechRecognitionService(),
            sentenceService: MockSentenceGenerationService(),
            audioService: MockAudioGenerationService(),
            modelContext: context,
            vocabularyHelp: vocabularyHelp,
            memoryUnlockService: SpriteMemoryUnlockService(modelContext: context),
            companionID: companionID
        )
        let result = GeneratedSentenceResult(
            targetText: "I was swamped today.",
            category: .work,
            vocabulary: [
                VocabCandidate(
                    surfaceText: "swamped",
                    meaningInContext: "忙翻了",
                    suggestedHelpState: .new
                ),
            ],
            deconstruction: [],
            promptVersion: "test"
        )

        viewModel.save(result: result, sourceText: "今天忙翻了")
        try await Task.sleep(nanoseconds: 50_000_000)

        let vocabItems = try context.fetch(FetchDescriptor<VocabItem>())
        let events = try context.fetch(FetchDescriptor<LearningEvent>())
        XCTAssertEqual(vocabItems.count, 1)
        XCTAssertEqual(vocabItems.first?.surfaceText, "swamped")
        XCTAssertTrue(events.contains { $0.eventType == .vocabAdded })
        XCTAssertTrue(events.contains { $0.eventType == .sentenceCreated })
        XCTAssertTrue(firstSentenceMemory.unlocked)
        XCTAssertTrue(events.contains {
            $0.eventType == .memoryUnlocked && $0.metadataJSON.contains("first_own_sentence")
        })
    }
}
