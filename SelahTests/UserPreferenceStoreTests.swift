import XCTest
import SwiftData
@testable import Selah

@MainActor
final class UserPreferenceStoreTests: XCTestCase {
    func testSavePersistsSettingsAndAdvancesUpdatedAt() throws {
        let schema = Schema([UserPreference.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let preference = UserPreference.default()
        context.insert(preference)
        try context.save()
        let originalUpdatedAt = preference.updatedAt

        preference.voiceProfile = .dailyBright
        preference.playbackSpeed = .normal
        preference.notificationEnabled = false
        preference.notificationTime = "07:30"

        let store = UserPreferenceStore(modelContext: context)
        try store.save(preference, now: originalUpdatedAt.addingTimeInterval(60))

        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<UserPreference>()).first)
        XCTAssertEqual(saved.voiceProfile, .dailyBright)
        XCTAssertEqual(saved.playbackSpeed, .normal)
        XCTAssertFalse(saved.notificationEnabled)
        XCTAssertEqual(saved.notificationTime, "07:30")
        XCTAssertEqual(saved.updatedAt, originalUpdatedAt.addingTimeInterval(60))
    }
}
