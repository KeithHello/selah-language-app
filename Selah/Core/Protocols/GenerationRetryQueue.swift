import Foundation

/// Local persistent retry queue for generation jobs.
/// Survives app termination; retries with exponential backoff.
protocol GenerationRetryQueue {
    /// Enqueue a generation job.
    func enqueue(_ job: GenerationJob) async throws

    /// Recover jobs left in progress when the app was terminated.
    func recoverInterruptedJobs() async throws

    /// Retry all due jobs with exponential backoff.
    func retryDueJobs(now: Date) async throws

    /// Mark a job as successfully completed.
    func markSucceeded(jobID: UUID) async throws

    /// Mark a job as failed with error information.
    func markFailed(jobID: UUID, error: GenerationError) async throws

    /// Cancel all pending jobs for a sentence (e.g., sentence deleted).
    func cancelAll(for sentenceID: UUID) async throws
}

// MARK: - Generation Error

struct GenerationError: Error {
    let code: String?
    let message: String
    let isRetryable: Bool
}
