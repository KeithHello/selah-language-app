import Foundation

enum BackgroundRefreshPolicy {
    static let taskIdentifier = "com.kdagentic.selah.refresh"
    static let minimumDelay: TimeInterval = 15 * 60

    static func earliestBeginDate(now: Date) -> Date {
        now.addingTimeInterval(minimumDelay)
    }
}

#if canImport(BackgroundTasks)
import BackgroundTasks

@MainActor
final class BackgroundRefreshScheduler {
    private var operation: (@MainActor () async -> Void)?

    @discardableResult
    func register(operation: @escaping @MainActor () async -> Void) -> Bool {
        self.operation = operation
        return BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundRefreshPolicy.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.run(refreshTask)
            }
        }
    }

    func schedule(now: Date = Date()) throws {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundRefreshPolicy.taskIdentifier
        )
        request.earliestBeginDate = BackgroundRefreshPolicy.earliestBeginDate(now: now)
        try BGTaskScheduler.shared.submit(request)
    }

    private func run(_ task: BGAppRefreshTask) async {
        let work = Task { @MainActor [weak self] in
            await self?.operation?()
        }
        task.expirationHandler = {
            work.cancel()
        }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)

        // Every execution schedules the next opportunity. iOS still decides
        // whether and when the refresh receives runtime.
        try? schedule()
    }
}
#endif
