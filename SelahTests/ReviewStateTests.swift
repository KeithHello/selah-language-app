import XCTest
@testable import Selah

/// Tests for the ReviewState model's scheduling logic.
/// Covers: initialization, applyRecall transitions, markListened,
/// and isDue computation.
final class ReviewStateTests: XCTestCase {

    func testReviewStateInitialization() {
        let sentenceID = UUID()
        let state = ReviewState(sentenceID: sentenceID)

        XCTAssertEqual(state.sentenceID, sentenceID)
        XCTAssertEqual(state.state, .new)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.lapseCount, 0)
        XCTAssertNil(state.lastRecallSignal)
        XCTAssertTrue(state.isDue) // nextReviewAt defaults to now
    }

    func testReviewStateCustomInit() {
        let sentenceID = UUID()
        let tomorrow = Date().addingTimeInterval(86400)
        let state = ReviewState(
            sentenceID: sentenceID,
            state: .learning,
            nextReviewAt: tomorrow,
            intervalDays: 3,
            lapseCount: 2
        )

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 3)
        XCTAssertEqual(state.lapseCount, 2)
        XCTAssertFalse(state.isDue)
    }

    // MARK: - applyRecall tests

    func testApplyRecallNewToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .new)
        state.applyRecall(.clear)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.lastRecallSignal, .clear)
        XCTAssertEqual(state.lapseCount, 0) // clear resets lapses
    }

    func testApplyRecallLearningClearToFamiliar() {
        let state = ReviewState(sentenceID: UUID(), state: .learning)
        state.applyRecall(.clear)

        XCTAssertEqual(state.state, .familiar)
        XCTAssertEqual(state.intervalDays, 3)
        XCTAssertEqual(state.lastRecallSignal, .clear)
    }

    func testApplyRecallLearningAlmost() {
        let state = ReviewState(sentenceID: UUID(), state: .learning)
        state.applyRecall(.almost)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.lastRecallSignal, .almost)
    }

    func testApplyRecallLearningFailed() {
        let state = ReviewState(sentenceID: UUID(), state: .learning)
        state.applyRecall(.failed)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.lastRecallSignal, .failed)
        XCTAssertEqual(state.lapseCount, 1)
    }

    func testApplyRecallFamiliarClearToQuiet() {
        let state = ReviewState(sentenceID: UUID(), state: .familiar)
        state.applyRecall(.clear)

        XCTAssertEqual(state.state, .quiet)
        XCTAssertEqual(state.intervalDays, 7)
    }

    func testApplyRecallFamiliarAlmostToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .familiar)
        state.applyRecall(.almost)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
    }

    func testApplyRecallFamiliarFailedToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .familiar)
        state.applyRecall(.failed)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.lapseCount, 1)
    }

    func testApplyRecallQuietClearStaysQuiet() {
        let state = ReviewState(sentenceID: UUID(), state: .quiet)
        state.applyRecall(.clear)

        XCTAssertEqual(state.state, .quiet)
        XCTAssertEqual(state.intervalDays, 30)
    }

    func testApplyRecallQuietAlmostToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .quiet)
        state.applyRecall(.almost)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
    }

    func testApplyRecallQuietFailedToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .quiet)
        state.applyRecall(.failed)

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.lapseCount, 1)
    }

    func testApplyRecallClearResetsLapseCount() {
        let state = ReviewState(sentenceID: UUID(), state: .learning, lapseCount: 3)
        state.applyRecall(.clear)

        XCTAssertEqual(state.lapseCount, 0)
    }

    func testApplyRecallFailedIncrementsLapseCount() {
        let state = ReviewState(sentenceID: UUID(), state: .learning, lapseCount: 1)
        state.applyRecall(.failed)

        XCTAssertEqual(state.lapseCount, 2)
    }

    func testApplyRecallAlmostDoesNotChangeLapseCount() {
        let state = ReviewState(sentenceID: UUID(), state: .learning, lapseCount: 2)
        state.applyRecall(.almost)

        XCTAssertEqual(state.lapseCount, 2) // unchanged
    }

    // MARK: - markListened tests

    func testMarkListenedFromNewToLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .new)
        state.markListened()

        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)
    }

    func testMarkListenedDoesNotChangeFromLearning() {
        let state = ReviewState(sentenceID: UUID(), state: .learning)
        state.markListened()

        XCTAssertEqual(state.state, .learning) // unchanged
    }

    func testMarkListenedDoesNotChangeFromFamiliar() {
        let state = ReviewState(sentenceID: UUID(), state: .familiar)
        state.markListened()

        XCTAssertEqual(state.state, .familiar) // unchanged
    }

    // MARK: - isDue tests

    func testIsDueWhenNextReviewInPast() {
        let state = ReviewState(
            sentenceID: UUID(),
            nextReviewAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        XCTAssertTrue(state.isDue)
    }

    func testIsDueWhenNextReviewInFuture() {
        let state = ReviewState(
            sentenceID: UUID(),
            nextReviewAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
        XCTAssertFalse(state.isDue)
    }

    // MARK: - Full lifecycle test

    func testFullSentenceLifecycle() {
        let state = ReviewState(sentenceID: UUID(), state: .new)

        // 1. Listen -> moves to learning
        state.markListened()
        XCTAssertEqual(state.state, .learning)

        // 2. Practice: clear -> familiar, review in 3 days
        state.applyRecall(.clear)
        XCTAssertEqual(state.state, .familiar)
        XCTAssertEqual(state.intervalDays, 3)

        // 3. Practice again: clear -> quiet, review in 7 days
        state.applyRecall(.clear)
        XCTAssertEqual(state.state, .quiet)
        XCTAssertEqual(state.intervalDays, 7)

        // 4. Practice: almost -> back to learning
        state.applyRecall(.almost)
        XCTAssertEqual(state.state, .learning)
        XCTAssertEqual(state.intervalDays, 1)

        // 5. Practice: clear -> familiar again, review in 3 days
        state.applyRecall(.clear)
        XCTAssertEqual(state.state, .familiar)
        XCTAssertEqual(state.intervalDays, 3)
    }
}
