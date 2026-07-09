import Foundation

/// Repository for sprite companion data.
/// MVP ships one active companion; multi-companion ready.
protocol CompanionRepository {
    /// Get the currently active companion.
    func getActiveCompanion() async throws -> Companion

    /// Set a different companion as active (future use).
    func setActiveCompanion(_ id: UUID) async throws

    /// Get all owned companions (future use).
    func getOwnedCompanions() async throws -> [Companion]

    /// Create the default seed sprite companion.
    func createDefaultCompanion(name: String) async throws -> Companion

    /// Initialize all sprite memories for a companion.
    func initializeMemories(for companionID: UUID) async throws

    /// Unlock a specific memory by key.
    func unlockMemory(companionID: UUID, memoryKey: String) async throws -> SpriteMemory?

    /// Get all memories for a companion, grouped by category.
    func getMemories(for companionID: UUID) async throws -> [SpriteMemory]

    /// Update companion mood based on recent activity.
    func updateMood(companionID: UUID, daysSinceLastInteraction: Int) async throws

    /// Update companion decoration based on day count.
    func updateDecoration(companionID: UUID) async throws
}
