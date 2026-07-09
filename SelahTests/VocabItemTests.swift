import XCTest
@testable import Selah

/// Tests for the VocabItem model's state transition logic.
/// Covers: initialization, markEncounter (success/failure),
/// markUsed, reAddToFocus, and user-facing display properties.
final class VocabItemTests: XCTestCase {

    func testVocabItemInitialization() {
        let sentenceID = UUID()
        let item = VocabItem(
            sentenceID: sentenceID,
            surfaceText: "swamped",
            meaningInContext: "忙翻了",
            helpState: .learning,
            manuallyAdded: false
        )

        XCTAssertEqual(item.sentenceID, sentenceID)
        XCTAssertEqual(item.surfaceText, "swamped")
        XCTAssertEqual(item.meaningInContext, "忙翻了")
        XCTAssertEqual(item.helpState, .learning)
        XCTAssertFalse(item.manuallyAdded)
        XCTAssertEqual(item.successCount, 0)
        XCTAssertEqual(item.failureCount, 0)
        XCTAssertTrue(item.activeHelpVisible) // learning -> visible
        XCTAssertNil(item.lastSeenAt)
        XCTAssertNil(item.lastUsedAt)
    }

    func testVocabItemDefaultState() {
        let item = VocabItem(
            sentenceID: UUID(),
            surfaceText: "test",
            meaningInContext: "測試"
        )

        XCTAssertEqual(item.helpState, .new)
        XCTAssertTrue(item.activeHelpVisible) // new -> visible
    }

    func testVocabItemUserFacingGroup() {
        let newItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .new)
        XCTAssertEqual(newItem.userFacingGroup, "仍在關注")

        let learningItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .learning)
        XCTAssertEqual(learningItem.userFacingGroup, "仍在關注")

        let familiarItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .familiar)
        XCTAssertEqual(familiarItem.userFacingGroup, "已比較熟")

        let ownedItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .owned)
        XCTAssertEqual(ownedItem.userFacingGroup, "已比較熟")
    }

    func testVocabItemStatusHint() {
        let newItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .new)
        XCTAssertEqual(newItem.statusHint, "句子拆解中")

        let learningItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .learning)
        XCTAssertEqual(learningItem.statusHint, "下一次還想再看")

        let familiarItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .familiar)
        XCTAssertEqual(familiarItem.statusHint, "不再主動拆解")

        let ownedItem = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .owned)
        XCTAssertEqual(ownedItem.statusHint, "你已經用出來過")
    }

    func testMarkEncounterSuccessTransitionsToLearning() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .new)

        item.markEncounter(success: true)
        XCTAssertEqual(item.successCount, 1)
        XCTAssertNotNil(item.lastSeenAt)
        // New state does not transition on first success
        XCTAssertEqual(item.helpState, .new)
    }

    func testMarkEncounterSuccessTransitionsLearningToFamiliar() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .learning)

        // First success
        item.markEncounter(success: true)
        XCTAssertEqual(item.successCount, 1)
        XCTAssertEqual(item.helpState, .learning) // still learning after 1

        // Second success -> familiar
        item.markEncounter(success: true)
        XCTAssertEqual(item.successCount, 2)
        XCTAssertEqual(item.helpState, .familiar)
        XCTAssertFalse(item.activeHelpVisible)
    }

    func testMarkEncounterFailureTransitionsFamiliarToLearning() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .familiar)

        // First failure
        item.markEncounter(success: false)
        XCTAssertEqual(item.failureCount, 1)
        XCTAssertEqual(item.helpState, .familiar) // still familiar after 1

        // Second failure -> learning
        item.markEncounter(success: false)
        XCTAssertEqual(item.helpState, .learning)
        XCTAssertTrue(item.activeHelpVisible)
        XCTAssertEqual(item.failureCount, 0) // reset after transition
    }

    func testMarkEncounterFailureTransitionsOwnedToLearning() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .owned)

        item.markEncounter(success: false)
        XCTAssertEqual(item.failureCount, 1)

        item.markEncounter(success: false)
        XCTAssertEqual(item.helpState, .learning)
        XCTAssertTrue(item.activeHelpVisible)
    }

    func testMarkUsed() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .learning)

        item.markUsed()

        XCTAssertEqual(item.helpState, .owned)
        XCTAssertFalse(item.activeHelpVisible)
        XCTAssertNotNil(item.lastUsedAt)
        XCTAssertTrue(item.isOwned)
    }

    func testReAddToFocus() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .familiar)

        item.reAddToFocus()

        XCTAssertEqual(item.helpState, .learning)
        XCTAssertTrue(item.activeHelpVisible)
        XCTAssertEqual(item.failureCount, 0)
    }

    func testIsOwnedProperty() {
        let item = VocabItem(sentenceID: UUID(), surfaceText: "a", meaningInContext: "a", helpState: .new)
        XCTAssertFalse(item.isOwned)

        item.markUsed()
        XCTAssertTrue(item.isOwned)
    }

    func testManuallyAddedFlag() {
        let item = VocabItem(
            sentenceID: UUID(),
            surfaceText: "test",
            meaningInContext: "測試",
            helpState: .new,
            manuallyAdded: true
        )
        XCTAssertTrue(item.manuallyAdded)
    }
}
