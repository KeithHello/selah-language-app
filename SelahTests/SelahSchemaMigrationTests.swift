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

    func testV2StoreMigratesToV3AndAddsCaptureDraftModels() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("selah-v2-to-v3-\(UUID().uuidString).store")
        try createV2Store(at: storeURL)

        let v3Schema = Schema(versionedSchema: SelahSchemaV3.self)
        let configuration = ModelConfiguration(
            "SelahMigrationV3",
            schema: v3Schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: v3Schema,
            migrationPlan: SelahMigrationPlan.self,
            configurations: [configuration]
        )
        let capture = CaptureDraft(
            rawTranscript: "呃，我今天很累。",
            normalizedTranscript: "呃，我今天很累。"
        )
        let segment = LearningSegmentDraft(
            captureID: capture.id,
            orderIndex: 0,
            originalText: "呃，我今天很累。",
            sourceText: "我今天很累。"
        )
        capture.segments = [segment]
        container.mainContext.insert(capture)
        try container.mainContext.save()

        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<CaptureDraft>()).count,
            1
        )
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<LearningSegmentDraft>()).count,
            1
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

    private func createV2Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: SelahSchemaV2.self)
        let configuration = ModelConfiguration(
            "SelahMigrationV2Fixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        _ = try ModelContainer(for: schema, configurations: [configuration])
    }
}
