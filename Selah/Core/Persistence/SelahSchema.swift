import Foundation
import SwiftData

@Model
final class PersistenceMetadata {
    @Attribute(.unique) var id: UUID
    var schemaVersion: Int
    var updatedAt: Date

    init(id: UUID = UUID(), schemaVersion: Int) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.updatedAt = Date()
    }
}

enum SelahSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = SelahSchemaModels.v1
}

enum SelahSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = SelahSchemaModels.v1 + [
        PersistenceMetadata.self,
    ]
}

enum SelahSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static let models: [any PersistentModel.Type] = SelahSchemaModels.v2 + [
        CaptureDraft.self,
        LearningSegmentDraft.self,
    ]
}

enum SelahMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SelahSchemaV1.self,
        SelahSchemaV2.self,
        SelahSchemaV3.self,
    ]

    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: SelahSchemaV1.self, toVersion: SelahSchemaV2.self),
        .lightweight(fromVersion: SelahSchemaV2.self, toVersion: SelahSchemaV3.self),
    ]
}

private enum SelahSchemaModels {
    static let v1: [any PersistentModel.Type] = [
        Sentence.self,
        VocabItem.self,
        ReviewState.self,
        AudioAsset.self,
        GenerationJob.self,
        Companion.self,
        SpriteMemory.self,
        UserPreference.self,
        LearningEvent.self,
    ]

    static let v2: [any PersistentModel.Type] = v1 + [
        PersistenceMetadata.self,
    ]
}
