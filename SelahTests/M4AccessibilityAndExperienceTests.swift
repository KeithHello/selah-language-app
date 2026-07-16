import XCTest
@testable import Selah

private actor FakeNotificationClient: LocalNotificationClient {
    private(set) var authorizationResult: Bool
    private(set) var addedRequests: [LocalNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []

    init(authorizationResult: Bool = true) {
        self.authorizationResult = authorizationResult
    }

    func requestAuthorization() async throws -> Bool {
        authorizationResult
    }

    func add(_ request: LocalNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func remove(identifier: String) async {
        removedIdentifiers.append(identifier)
    }
}

final class M4AccessibilityAndExperienceTests: XCTestCase {
    func testNotificationTimeParsesValidTimeAndFallsBackSafely() {
        XCTAssertEqual(LocalNotificationService.parseTime("07:05", fallback: "20:00").hour, 7)
        XCTAssertEqual(LocalNotificationService.parseTime("07:05", fallback: "20:00").minute, 5)
        XCTAssertEqual(LocalNotificationService.parseTime("25:61", fallback: "20:00").hour, 20)
        XCTAssertEqual(LocalNotificationService.parseTime("25:61", fallback: "20:00").minute, 0)
        XCTAssertEqual(LocalNotificationService.parseTime(nil, fallback: "09:30").hour, 9)
        XCTAssertEqual(LocalNotificationService.parseTime(nil, fallback: "09:30").minute, 30)
        XCTAssertEqual(LocalNotificationService.parseTime("garbage", fallback: "20:00").hour, 20)
        XCTAssertEqual(LocalNotificationService.parseTime("", fallback: "09:30").hour, 9)
    }

    func testNotificationServiceSchedulesSafeReminderAndCancelsWhenDisabled() async throws {
        let client = FakeNotificationClient()
        let service = LocalNotificationService(client: client)
        let preference = LocalNotificationPreferences(enabled: true, time: "08:45")

        try await service.synchronize(preference: preference)
        let requests = await client.addedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.hour, 8)
        XCTAssertEqual(requests.first?.minute, 45)
        XCTAssertFalse(requests[0].body.contains("今天"))
        XCTAssertFalse(requests[0].body.contains("累"))

        let disabledPreference = LocalNotificationPreferences(enabled: false, time: "08:45")
        try await service.synchronize(preference: disabledPreference)
        let removed = await client.removedIdentifiers
        XCTAssertEqual(removed, [LocalNotificationRequest.dailyReminderIdentifier])
    }

    func testWidgetSnapshotBoundsStringsAndNeverCarriesSentenceText() {
        let sentence = "這是一段不應該出現在 Widget 摘要的個人句子"
        let snapshot = WidgetReadySnapshotBuilder().build(
            counts: WidgetReadyCounts(todaySentenceCount: -1, listenedCount: 2, dueReviewCount: 3),
            recommendation: String(repeating: "下一步 ", count: 20),
            companionDisplayName: String(repeating: "小豆", count: 20),
            generatedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(snapshot.todaySentenceCount, 0)
        XCTAssertLessThanOrEqual(snapshot.recommendation.count, WidgetReadySnapshot.maxActionLength)
        XCTAssertLessThanOrEqual(snapshot.companionDisplayName.count, WidgetReadySnapshot.maxCompanionNameLength)
        XCTAssertFalse(snapshot.recommendation.contains(sentence))
        XCTAssertFalse(snapshot.companionDisplayName.contains(sentence))
        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 123))
    }

    func testWidgetSnapshotStorePersistsSharedContract() throws {
        let suite = "SelahWidgetTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let snapshot = WidgetReadySnapshotBuilder().build(
            counts: WidgetReadyCounts(todaySentenceCount: 1, listenedCount: 2, dueReviewCount: 3),
            recommendation: "練習一句",
            companionDisplayName: "小豆",
            generatedAt: Date(timeIntervalSince1970: 321)
        )

        try WidgetSnapshotStore(defaults: defaults).save(snapshot)

        let data = try XCTUnwrap(defaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        XCTAssertEqual(try JSONDecoder().decode(WidgetReadySnapshot.self, from: data), snapshot)
    }

    func testReduceMotionPolicyDisablesAnimations() {
        XCTAssertTrue(SelahMotionPolicy.policy(reduceMotion: false).allowsAnimation)
        XCTAssertFalse(SelahMotionPolicy.policy(reduceMotion: true).allowsAnimation)
        XCTAssertEqual(SelahMotionPolicy.policy(reduceMotion: true), .reduced)
    }

    func testNotificationServiceThrowsWhenPermissionDenied() async throws {
        let client = FakeNotificationClient(authorizationResult: false)
        let service = LocalNotificationService(client: client)
        let preference = LocalNotificationPreferences(enabled: true, time: "08:45")

        do {
            try await service.synchronize(preference: preference)
            XCTFail("Expected permissionDenied error")
        } catch LocalNotificationError.permissionDenied {
            // expected
        }

        let requests = await client.addedRequests
        XCTAssertEqual(requests.count, 0)
    }

    func testContrastHelpersApplyWCAGThresholds() {
        XCTAssertTrue(SelahContrast.meetsNormalText(foregroundHex: "#1A1614", backgroundHex: "#FFFFFF"))
        XCTAssertFalse(SelahContrast.meetsNormalText(foregroundHex: "#A9A49E", backgroundHex: "#FFFFFF"))
        XCTAssertTrue(SelahContrast.meetsLargeText(foregroundHex: "#706B65", backgroundHex: "#FFFFFF"))
        XCTAssertNil(SelahContrast.ratio(foregroundHex: "not-a-color", backgroundHex: "#FFFFFF"))
    }
}
