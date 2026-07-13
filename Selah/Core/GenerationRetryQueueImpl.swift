import Foundation

/// Local persistent generation retry queue.
actor GenerationRetryQueueImpl: GenerationRetryQueue {

    private let jobRepo: GenerationJobRepository
    private let audioService: AudioGenerationService
    private let breaker: CapabilityCircuitBreaker
    private let retryPolicy: RetryPolicy
    private let maxJobsPerRun: Int

    init(
        jobRepo: GenerationJobRepository,
        audioService: AudioGenerationService,
        breaker: CapabilityCircuitBreaker = CapabilityCircuitBreaker(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        maxJobsPerRun: Int = 3
    ) {
        self.jobRepo = jobRepo
        self.audioService = audioService
        self.breaker = breaker
        self.retryPolicy = retryPolicy
        self.maxJobsPerRun = max(1, maxJobsPerRun)
    }

    func enqueue(_ job: GenerationJob) async throws {
        try await jobRepo.save(job)
    }

    func recoverInterruptedJobs() async throws {
        try await jobRepo.recoverInterruptedJobs()
    }

    func retryDueJobs(now: Date) async throws {
        let fetchedJobs = try await jobRepo.fetchPending(retryable: true, now: now)
        let pending = Array(fetchedJobs.filter { $0.isRetryable }.prefix(maxJobsPerRun))

        for job in pending {
            guard await breaker.canProceed(now: now) else {
                job.nextRetryAt = now.addingTimeInterval(retryPolicy.delay(afterAttempt: job.retryCount + 1))
                try await jobRepo.save(job)
                continue
            }
            job.markInProgress()
            try await jobRepo.save(job)

            do {
                // Attempt the retry based on job type
                switch job.jobType {
                case .audioGeneration, .audioRegeneration:
                    // Trigger audio generation
                    _ = try await audioService.generateAudio(
                        sentenceID: job.sentenceID,
                        targetText: "", // will be fetched by the real service
                        voiceProfile: .gentleNatural,
                        reason: job.jobType == .audioRegeneration
                            ? .manualRegeneration
                            : .initialGeneration
                    )
                case .sentenceGeneration:
                    // Sentence generation retries happen in the UI flow
                    break
                }

                await breaker.recordSuccess()
                job.markCompleted()
                try await jobRepo.save(job)
            } catch let error as SelahAPIError {
                await breaker.recordFailure(kind: error.failureKind, now: now)
                job.markFailed(errorCode: error.failureKind == .authentication ? "authentication" : "retry_failed")
                try await jobRepo.save(job)
            } catch {
                await breaker.recordFailure(kind: .permanent, now: now)
                job.markFailed(errorCode: "retry_failed")
                try await jobRepo.save(job)
            }
        }
    }

    func circuitSnapshot() async -> (state: CapabilityCircuitBreaker.State, consecutiveFailures: Int) {
        await breaker.snapshot()
    }

    func markSucceeded(jobID: UUID) async throws {
        guard let job = try await jobRepo.fetch(id: jobID) else { return }
        job.markCompleted()
        try await jobRepo.save(job)
    }

    func markFailed(jobID: UUID, error: GenerationError) async throws {
        guard let job = try await jobRepo.fetch(id: jobID) else { return }
        job.markFailed(errorCode: error.code)
        try await jobRepo.save(job)
    }

    func cancelAll(for sentenceID: UUID) async throws {
        try await jobRepo.cancelAll(for: sentenceID)
    }
}
