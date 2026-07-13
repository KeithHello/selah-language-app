import Foundation
#if canImport(Network)
import Network
#endif

// MARK: - Connectivity

enum ConnectivityStatus: Equatable, Sendable {
    case unknown
    case offline
    case online

    var isOnline: Bool {
        self == .online
    }
}

protocol ConnectivityProviding: Sendable {
    func currentStatus() async -> ConnectivityStatus
    func refresh() async -> ConnectivityStatus
}

/// Actor-isolated reachability service. The probe is injectable so offline
/// behavior can be tested without relying on the device network.
actor ConnectivityMonitor: ConnectivityProviding {
    private var status: ConnectivityStatus
    private let probe: @Sendable () async -> ConnectivityStatus

    init(
        initialStatus: ConnectivityStatus = .unknown,
        probe: @escaping @Sendable () async -> ConnectivityStatus = ConnectivityMonitor.defaultProbe
    ) {
        self.status = initialStatus
        self.probe = probe
    }

    func currentStatus() -> ConnectivityStatus {
        status
    }

    func refresh() async -> ConnectivityStatus {
        let nextStatus = await probe()
        status = nextStatus
        return nextStatus
    }

    /// Allows the app lifecycle or a test harness to publish a known path state.
    func setStatus(_ status: ConnectivityStatus) {
        self.status = status
    }

    private static func defaultProbe() async -> ConnectivityStatus {
        #if canImport(Network)
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.selah.connectivity")
            monitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied ? .online : .offline)
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
        #else
        return .unknown
        #endif
    }
}

// MARK: - Pending Remote Work

enum PendingOperation: Equatable, Sendable {
    case sentenceTranslation(sourceText: String)
    case audioGeneration(sentenceID: UUID)

    var message: String {
        switch self {
        case .sentenceTranslation:
            return "目前離線，這句中文已留在本機；連線恢復後再翻成英文。"
        case .audioGeneration:
            return "目前離線，句子已保存；聲音會在連線恢復後準備好。"
        }
    }
}
