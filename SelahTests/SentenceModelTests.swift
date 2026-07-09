import XCTest
@testable import Selah

/// Tests for the Sentence SwiftData model.
/// Tests cover initialization, computed properties, and convenience accessors.
/// Note: SwiftData @Model classes require a ModelContainer for relationship
/// management. These tests verify the non-persisted model logic only.
final class SentenceModelTests: XCTestCase {

    func testSentenceInitialization() {
        let sentence = Sentence(
            sourceText: "今天工作忙翻了",
            targetText: "I was swamped at work today.",
            category: .work,
            origin: .userRecording
        )

        XCTAssertEqual(sentence.sourceText, "今天工作忙翻了")
        XCTAssertEqual(sentence.targetText, "I was swamped at work today.")
        XCTAssertEqual(sentence.category, .work)
        XCTAssertEqual(sentence.origin, .userRecording)
        XCTAssertEqual(sentence.sourceLanguage, "zh-Hant")
        XCTAssertEqual(sentence.targetLanguage, "en")
        XCTAssertFalse(sentence.archived)
        XCTAssertTrue(sentence.audioAssets.isEmpty)
        XCTAssertTrue(sentence.vocabItems.isEmpty)
        XCTAssertTrue(sentence.learningEvents.isEmpty)
        XCTAssertTrue(sentence.generationJobs.isEmpty)
        XCTAssertNil(sentence.reviewState)
        XCTAssertNil(sentence.previewedAt)
        XCTAssertNil(sentence.listenCompletedAt)
    }

    func testSentenceDefaultCategory() {
        let sentence = Sentence(sourceText: "test", targetText: "test")
        XCTAssertEqual(sentence.category, .dailyLife)
        XCTAssertEqual(sentence.origin, .userRecording)
    }

    func testSentenceIsPracticeReady() {
        let sentence = Sentence(sourceText: "test", targetText: "test")

        // Not ready without listen completed
        XCTAssertFalse(sentence.isPracticeReady)

        // Ready after listen completed
        sentence.listenCompletedAt = Date()
        XCTAssertTrue(sentence.isPracticeReady)

        // Not ready if archived
        sentence.archived = true
        XCTAssertFalse(sentence.isPracticeReady)
    }

    func testSentenceIsPreviewedNotListened() {
        let sentence = Sentence(sourceText: "test", targetText: "test")

        // Not previewed
        XCTAssertFalse(sentence.isPreviewedNotListened)

        // Previewed but not listened
        sentence.previewedAt = Date()
        XCTAssertTrue(sentence.isPreviewedNotListened)

        // Previewed and listened -> false
        sentence.listenCompletedAt = Date()
        XCTAssertFalse(sentence.isPreviewedNotListened)

        // Archived -> false
        sentence.archived = true
        XCTAssertFalse(sentence.isPreviewedNotListened)
    }

    func testSentenceCategorySetter() {
        let sentence = Sentence(sourceText: "test", targetText: "test")

        sentence.category = .friends
        XCTAssertEqual(sentence.category, .friends)
        XCTAssertEqual(sentence.categoryRaw, "friends")

        sentence.category = .vent
        XCTAssertEqual(sentence.category, .vent)
        XCTAssertEqual(sentence.categoryRaw, "vent")
    }

    func testSentenceOriginSetter() {
        let sentence = Sentence(sourceText: "test", targetText: "test")

        sentence.origin = .systemSeed
        XCTAssertEqual(sentence.origin, .systemSeed)
        XCTAssertEqual(sentence.originRaw, "system_seed")
    }

    func testSentenceWithDeconstructionAndVocab() {
        let deconJSON = """
        [{"surfaceText":"swamped","meaning":"忙翻了","type":"phrase"}]
        """
        let vocabJSON = """
        [{"surfaceText":"swamped","meaningInContext":"忙翻了","suggestedHelpState":"learning"}]
        """

        let sentence = Sentence(
            sourceText: "今天工作忙翻了",
            targetText: "I was swamped at work today.",
            category: .work,
            origin: .userRecording,
            deconstructionJSON: deconJSON,
            vocabCandidatesJSON: vocabJSON
        )

        XCTAssertEqual(sentence.deconstructionJSON, deconJSON)
        XCTAssertEqual(sentence.vocabCandidatesJSON, vocabJSON)
    }
}
