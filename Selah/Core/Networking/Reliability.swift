import Foundation

/// The two remote capabilities that can be paused independently when a backend
/// is temporarily unhealthy. Local sentence data remains usable in either state.
enum ReliabilityCapability: String, Codable, CaseIterable {
    case sentenceGeneration
    case audioGeneration
}

enum NetworkFailureKind: Equatable {
    case offline
    case timeout
    case rateLimited
    case serverTransient
    case authentication
    case clientInput
    case decoding
    case permanent
}

/// Bounded retry policy shared by remote generation requests.
struct RetryPolicy: Equatable {
    let maxAttempts: Int
    let delays: [TimeInterval]
    let jitter: TimeInterval

    init(maxAttempts: Int = 3, delays: [TimeInterval] = [1, 3, 10], jitter: TimeInterval = 0) {
        self.maxAttempts = max(1, maxAttempts)
        self.delays = delays.isEmpty ? [1] : delays
        self.jitter = max(0, jitter)
    }

    func delay(afterAttempt attempt: Int, retryAfter: TimeInterval? = nil) -> TimeInterval {
        if let retryAfter, retryAfter >= 0 {
            return min(retryAfter, 300)
        }
        let index = min(max(attempt - 1, 0), delays.count - 1)
        return min(max(delays[index], 0) + jitter, 300)
    }
}

/// Actor-isolated circuit breaker. Three transient failures open the circuit;
/// after the cooldown, exactly one request is allowed as the half-open probe.
actor CapabilityCircuitBreaker {
    enum State: Equatable {
        case closed
        case open(until: Date)
        case halfOpen
    }

    private(set) var state: State = .closed
    private(set) var consecutiveFailures = 0
    private let failureThreshold: Int
    private let cooldown: TimeInterval
    private var probeInFlight = false

    init(failureThreshold: Int = 3, cooldown: TimeInterval = 30) {
        self.failureThreshold = max(1, failureThreshold)
        self.cooldown = max(0, cooldown)
    }

    func canProceed(now: Date = Date()) -> Bool {
        switch state {
        case .closed:
            return true
        case .open(let until) where now >= until:
            state = .halfOpen
            probeInFlight = true
            return true
        case .open:
            return false
        case .halfOpen:
            guard !probeInFlight else { return false }
            probeInFlight = true
            return true
        }
    }

    func recordSuccess() {
        state = .closed
        consecutiveFailures = 0
        probeInFlight = false
    }

    func recordFailure(kind: NetworkFailureKind, now: Date = Date()) {
        guard kind == .offline || kind == .timeout || kind == .rateLimited || kind == .serverTransient else {
            probeInFlight = false
            return
        }
        consecutiveFailures += 1
        if consecutiveFailures >= failureThreshold || state == .halfOpen {
            state = .open(until: now.addingTimeInterval(cooldown))
            probeInFlight = false
        }
    }

    func snapshot() -> (state: State, consecutiveFailures: Int) {
        (state, consecutiveFailures)
    }
}
