import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// The local reminder payload shared by the iOS adapter and package-level tests.
struct LocalNotificationRequest: Equatable, Sendable {
    static let dailyReminderIdentifier = "selah.daily-learning-reminder"

    let identifier: String
    let title: String
    let body: String
    let hour: Int
    let minute: Int

    var timeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

enum LocalNotificationError: Error, Equatable, Sendable {
    case permissionDenied
}

/// Sendable value extracted from SwiftData preferences before crossing into the actor.
struct LocalNotificationPreferences: Sendable, Equatable {
    let enabled: Bool
    let time: String?

    init(enabled: Bool, time: String?) {
        self.enabled = enabled
        self.time = time
    }
}

/// Boundary for UserNotifications. Tests can inject an in-memory client.
protocol LocalNotificationClient: Sendable {
    func requestAuthorization() async throws -> Bool
    func add(_ request: LocalNotificationRequest) async throws
    func remove(identifier: String) async
}

/// Schedules one privacy-safe daily reminder. The service never receives sentence text.
actor LocalNotificationService {
    static let defaultReminderTime = "20:00"

    private let client: any LocalNotificationClient
    init(client: any LocalNotificationClient) {
        self.client = client
    }

    func synchronize(preference: LocalNotificationPreferences) async throws {
        guard preference.enabled else {
            await client.remove(identifier: LocalNotificationRequest.dailyReminderIdentifier)
            return
        }

        let (hour, minute) = Self.parseTime(preference.time, fallback: Self.defaultReminderTime)
        let authorized = try await client.requestAuthorization()
        guard authorized else { throw LocalNotificationError.permissionDenied }

        let request = LocalNotificationRequest(
            identifier: LocalNotificationRequest.dailyReminderIdentifier,
            title: "Selah",
            body: "今晚，留一點時間給自己的英文句子。",
            hour: hour,
            minute: minute
        )
        try await client.add(request)
    }

    func cancel() async {
        await client.remove(identifier: LocalNotificationRequest.dailyReminderIdentifier)
    }

    static func parseTime(_ value: String?, fallback: String) -> (hour: Int, minute: Int) {
        guard let parsed = parseValidTime(value ?? fallback) else {
            return parseValidTime(fallback) ?? (20, 0)
        }
        return parsed
    }

    private static func parseValidTime(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isNumber) }),
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }
        return (hour, minute)
    }
}

#if canImport(UserNotifications)
/// iOS adapter. It is conditionally compiled so the Swift Package remains portable.
struct UserNotificationsClient: LocalNotificationClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: LocalNotificationRequest) async throws {
        var components = request.timeComponents
        components.calendar = Calendar.current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        try await center.add(
            UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
        )
    }

    func remove(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
#endif
