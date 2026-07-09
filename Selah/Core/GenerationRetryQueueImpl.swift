import Foundation

/// Local persistent generation retry queue.
actor GenerationRetryQueueImpl: GenerationRetryQueue {

    private let jobRepo: GenerationJobRepository
    private let audioService: AudioGenerationService

    init(jobRepo: GenerationJobRepository, audioService: AudioGenerationService) {
        self.jobRepo = jobRepo
        self.audioService = audioService
    }

    func enqueue(_ job: GenerationJob) async throws {
        try await jobRepo.save(job)
    }

    func retryDueJobs(now: Date) async throws {
        let pending = try await jobRepo.fetchPending(retryable: true, now: now)

        for job in pending {
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

                job.markCompleted()
                try await jobRepo.save(job)
            } catch {
                job.markFailed(errorCode: "retry_failed")
                try await jobRepo.save(job)
            }
        }
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
