import XCTest
@testable import Selah

final class M4ReliabilityTests: XCTestCase {
    func testRetryPolicyUsesBoundedScheduleAndRetryAfter() {
        let policy = RetryPolicy()
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.delay(afterAttempt: 1), 1)
        XCTAssertEqual(policy.delay(afterAttempt: 2), 3)
        XCTAssertEqual(policy.delay(afterAttempt: 3), 10)
        XCTAssertEqual(policy.delay(afterAttempt: 2, retryAfter: 500), 300)
    }

    func testAPIErrorClassification() {
        XCTAssertEqual(SelahAPIError.serverError(429, "busy").failureKind, .rateLimited)
        XCTAssertEqual(SelahAPIError.serverError(503, "busy").failureKind, .serverTransient)
        XCTAssertEqual(SelahAPIError.serverError(401, "expired").failureKind, .authentication)
        XCTAssertEqual(SelahAPIError.serverError(422, "invalid").failureKind, .clientInput)
        XCTAssertEqual(SelahAPIError.networkError(URLError(.timedOut)).failureKind, .timeout)
        XCTAssertTrue(SelahAPIError.serverError(503, "busy").isRetryable)
        XCTAssertFalse(SelahAPIError.serverError(422, "invalid").isRetryable)
    }

    func testCircuitBreakerOpensAfterThreeTransientFailures() async {
        let breaker = CapabilityCircuitBreaker(cooldown: 30)
        let now = Date(timeIntervalSince1970: 100)
        let initialPermission = await breaker.canProceed(now: now)
        XCTAssertTrue(initialPermission)
        await breaker.recordFailure(kind: .serverTransient, now: now)
        await breaker.recordFailure(kind: .timeout, now: now)
        await breaker.recordFailure(kind: .rateLimited, now: now)
        let snapshot = await breaker.snapshot()
        XCTAssertEqual(snapshot.consecutiveFailures, 3)
        let blockedPermission = await breaker.canProceed(now: now.addingTimeInterval(1))
        XCTAssertFalse(blockedPermission)
        let probePermission = await breaker.canProceed(now: now.addingTimeInterval(31))
        XCTAssertTrue(probePermission)
        let secondProbePermission = await breaker.canProceed(now: now.addingTimeInterval(31))
        XCTAssertFalse(secondProbePermission)
        await breaker.recordSuccess()
        let recoveredPermission = await breaker.canProceed(now: now.addingTimeInterval(32))
        XCTAssertTrue(recoveredPermission)
    }
}
