import Foundation
import SwiftData

/// SwiftData-backed GenerationJob repository.
@MainActor
final class GenerationJobRepositoryImpl: GenerationJobRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ job: GenerationJob) async throws {
        if job.modelContext == nil {
            modelContext.insert(job)
        }
        try modelContext.save()
    }

    func fetch(id: UUID) async throws -> GenerationJob? {
        let descriptor = FetchDescriptor<GenerationJob>(
            predicate: #Predicate<GenerationJob> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchPending(retryable: Bool, now: Date) async throws -> [GenerationJob] {
        if retryable {
            let descriptor = FetchDescriptor<GenerationJob>(
                predicate: #Predicate<GenerationJob> {
                    ($0.statusRaw == "pending" || $0.statusRaw == "failed")
                    && ($0.nextRetryAt == nil || $0.nextRetryAt! <= now)
                },
                sortBy: [SortDescriptor(\GenerationJob.createdAt, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<GenerationJob>(
                predicate: #Predicate<GenerationJob> { $0.statusRaw == "pending" },
                sortBy: [SortDescriptor(\GenerationJob.createdAt, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        }
    }

    func recoverInterruptedJobs() async throws {
        let descriptor = FetchDescriptor<GenerationJob>(
            predicate: #Predicate<GenerationJob> { $0.statusRaw == "in_progress" }
        )
        for job in try modelContext.fetch(descriptor) {
            job.status = .failed
            job.lastErrorCode = "interrupted"
            job.nextRetryAt = Date()
            job.updatedAt = Date()
        }
        try modelContext.save()
    }

    func fetchAll(for sentenceID: UUID) async throws -> [GenerationJob] {
        let descriptor = FetchDescriptor<GenerationJob>(
            predicate: #Predicate<GenerationJob> { $0.sentenceID == sentenceID },
            sortBy: [SortDescriptor(\GenerationJob.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ job: GenerationJob) async throws {
        modelContext.delete(job)
        try modelContext.save()
    }

    func cancelAll(for sentenceID: UUID) async throws {
        let descriptor = FetchDescriptor<GenerationJob>(
            predicate: #Predicate<GenerationJob> {
                $0.sentenceID == sentenceID
                && ($0.statusRaw == "pending" || $0.statusRaw == "in_progress")
            }
        )
        for job in try modelContext.fetch(descriptor) {
            job.status = .failed
            job.lastErrorCode = "cancelled"
            job.nextRetryAt = nil
        }
        try modelContext.save()
    }
}
