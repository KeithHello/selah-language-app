import Foundation
import SwiftData

@MainActor
final class UserPreferenceStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ preference: UserPreference, now: Date = Date()) throws {
        preference.updatedAt = now
        try modelContext.save()
    }
}
