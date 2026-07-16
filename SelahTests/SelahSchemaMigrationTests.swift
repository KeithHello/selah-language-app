import XCTest
import SwiftData
@testable import Selah

@MainActor
final class SelahSchemaMigrationTests: XCTestCase {
    func testV1StoreMigratesToV2WithoutLosingPreferences() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("selah-v1-to-v2-\(UUID().uuidString).store")
        let preferenceID = UUID()

        try createV1Store(at: storeURL, preferenceID: preferenceID)

        let v2Schema = Schema(versionedSchema: SelahSchemaV2.self)
        let v2Configuration = ModelConfiguration(
            "SelahMigrationV2",
            schema: v2Schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: v2Schema,
            migrationPlan: SelahMigrationPlan.self,
            configurations: [v2Configuration]
        )

        let preferences = try container.mainContext.fetch(FetchDescriptor<UserPreference>())
        XCTAssertEqual(preferences.count, 1)
        XCTAssertEqual(preferences.first?.id, preferenceID)
        XCTAssertEqual(preferences.first?.onboardingCompleted, true)

        let metadata = PersistenceMetadata(schemaVersion: 2)
        container.mainContext.insert(metadata)
        try container.mainContext.save()
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<PersistenceMetadata>()).first?.schemaVersion,
            2
        )
    }

    private func createV1Store(at storeURL: URL, preferenceID: UUID) throws {
        let v1Schema = Schema(versionedSchema: SelahSchemaV1.self)
        let v1Configuration = ModelConfiguration(
            "SelahMigrationV1",
            schema: v1Schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: v1Schema,
            configurations: [v1Configuration]
        )
        let preference = UserPreference(id: preferenceID, onboardingCompleted: true)
        container.mainContext.insert(preference)
        try container.mainContext.save()
    }
}
