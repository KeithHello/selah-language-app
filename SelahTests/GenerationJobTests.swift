import XCTest
@testable import Selah

/// Tests for the GenerationJob model's retry queue logic.
/// Covers: initialization, status transitions, backoff calculation,
/// and retryability checks.
final class GenerationJobTests: XCTestCase {

    func testGenerationJobInitialization() {
        let sentenceID = UUID()
        let job = GenerationJob(
            sentenceID: sentenceID,
            jobType: .audioGeneration
        )

        XCTAssertEqual(job.sentenceID, sentenceID)
        XCTAssertEqual(job.jobType, .audioGeneration)
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.retryCount, 0)
        XCTAssertEqual(job.maxRetries, 5)
        XCTAssertNil(job.lastErrorCode)
        XCTAssertNil(job.nextRetryAt)
        XCTAssertEqual(job.payloadJSON, "{}")
        XCTAssertTrue(job.isRetryable)
    }

    func testGenerationJobCustomMaxRetries() {
        let job = GenerationJob(
            sentenceID: UUID(),
            jobType: .sentenceGeneration,
            maxRetries: 3
        )
        XCTAssertEqual(job.maxRetries, 3)
    }

    func testGenerationJobCustomPayload() {
        let job = GenerationJob(
            sentenceID: UUID(),
            jobType: .audioGeneration,
            payloadJSON: """
            {"voice":"gentle-natural","text":"Hello"}
            """
        )
        XCTAssertEqual(job.payloadJSON, """
        {"voice":"gentle-natural","text":"Hello"}
        """)
    }

    // MARK: - Status transitions

    func testMarkInProgress() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markInProgress()

        XCTAssertEqual(job.status, .inProgress)
    }

    func testMarkCompleted() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markInProgress()
        job.markCompleted()

        XCTAssertEqual(job.status, .completed)
        XCTAssertFalse(job.isRetryable)
    }

    func testMarkFailed() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markFailed(errorCode: "timeout")

        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(job.retryCount, 1)
        XCTAssertEqual(job.lastErrorCode, "timeout")
        XCTAssertNotNil(job.nextRetryAt)
        XCTAssertTrue(job.isRetryable) // retryCount(1) < maxRetries(5)
    }

    func testMarkFailedNilErrorCode() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markFailed(errorCode: nil)

        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(job.retryCount, 1)
        XCTAssertNil(job.lastErrorCode)
        XCTAssertTrue(job.isRetryable)
    }

    // MARK: - Backoff calculation

    func testBackoffSecondsForRetry0() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        // retryCount = 0 -> 2^0 = 1 second
        XCTAssertEqual(job.backoffSeconds, 1.0, accuracy: 0.01)
    }

    func testBackoffSecondsForRetry1() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markFailed(errorCode: "err")
        // retryCount = 1 -> 2^1 = 2 seconds
        XCTAssertEqual(job.backoffSeconds, 2.0, accuracy: 0.01)
    }

    func testBackoffSecondsForRetry5() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration, maxRetries: 10)

        // Fail 5 times
        for _ in 0..<5 {
            job.markFailed(errorCode: "err")
        }
        // retryCount = 5 -> 2^5 = 32 seconds
        XCTAssertEqual(job.backoffSeconds, 32.0, accuracy: 0.01)
    }

    func testBackoffSecondsCappedAt300() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration, maxRetries: 20)

        // Fail 10 times -> 2^10 = 1024 -> capped at 300
        for _ in 0..<10 {
            job.markFailed(errorCode: "err")
        }
        XCTAssertEqual(job.backoffSeconds, 300.0, accuracy: 0.01)
    }

    // MARK: - isRetryable

    func testIsRetryableWhenPending() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        XCTAssertTrue(job.isRetryable)
    }

    func testIsRetryableWhenCompleted() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration)
        job.markCompleted()
        XCTAssertFalse(job.isRetryable)
    }

    func testIsRetryableWhenMaxRetriesReached() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration, maxRetries: 2)

        job.markFailed(errorCode: "err")
        XCTAssertTrue(job.isRetryable) // retryCount=1 < maxRetries=2

        job.markFailed(errorCode: "err")
        XCTAssertFalse(job.isRetryable) // retryCount=2 == maxRetries=2
    }

    // MARK: - Job types

    func testAllJobTypes() {
        let types: [GenerationJobType] = [.sentenceGeneration, .audioGeneration, .audioRegeneration]
        XCTAssertEqual(types.count, 3)
    }

    // MARK: - Multiple failures sequence

    func testMultipleFailuresSequence() {
        let job = GenerationJob(sentenceID: UUID(), jobType: .audioGeneration, maxRetries: 5)

        // First failure
        job.markFailed(errorCode: "err1")
        XCTAssertEqual(job.retryCount, 1)
        XCTAssertEqual(job.backoffSeconds, 2.0, accuracy: 0.01)

        // Second failure
        job.markFailed(errorCode: "err2")
        XCTAssertEqual(job.retryCount, 2)
        XCTAssertEqual(job.backoffSeconds, 4.0, accuracy: 0.01)

        // Third failure
        job.markFailed(errorCode: "err3")
        XCTAssertEqual(job.retryCount, 3)
        XCTAssertEqual(job.backoffSeconds, 8.0, accuracy: 0.01)

        XCTAssertTrue(job.isRetryable) // 3 < 5
    }
}
