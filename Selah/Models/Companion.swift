import Foundation
import SwiftData

/// Sprite companion. MVP ships one active companion;
/// data model supports multiple companions later.
@Model
final class Companion {
    @Attribute(.unique) var id: UUID

    var companionKeyRaw: String        // CompanionKey raw value
    var displayName: String
    var active: Bool
    var acquiredAt: Date
    var moodRaw: String                // SpriteMood raw value
    var decorationStageRaw: String     // DecorationStage raw value
    var lastInteractionAt: Date?

    // Relationships
    @Relationship(deleteRule: .cascade) var memories: [SpriteMemory]

    // MARK: - Convenience

    var companionKey: CompanionKey {
        get { CompanionKey(rawValue: companionKeyRaw) ?? .seedSprite }
        set { companionKeyRaw = newValue.rawValue }
    }

    var mood: SpriteMood {
        get { SpriteMood(rawValue: moodRaw) ?? .neutral }
        set { moodRaw = newValue.rawValue }
    }

    var decorationStage: DecorationStage {
        get { DecorationStage(rawValue: decorationStageRaw) ?? .none }
        set { decorationStageRaw = newValue.rawValue }
    }

    /// Days since companion was acquired.
    var daysSinceAcquired: Int {
        Calendar.current.dateComponents([.day], from: acquiredAt, to: Date()).day ?? 0
    }

    /// Update decoration based on day count.
    func updateDecoration() {
        decorationStage = DecorationStage.stage(for: daysSinceAcquired)
    }

    /// Update mood based on recent activity.
    func updateMood(daysSinceLastInteraction: Int) {
        switch daysSinceLastInteraction {
        case 0...2:  mood = .happy
        case 3...6:  mood = .neutral
        default:     mood = .quiet
        }
    }

    init(
        id: UUID = UUID(),
        companionKey: CompanionKey = .seedSprite,
        displayName: String,
        active: Bool = true
    ) {
        self.id = id
        self.companionKeyRaw = companionKey.rawValue
        self.displayName = displayName
        self.active = active
        self.acquiredAt = Date()
        self.moodRaw = SpriteMood.neutral.rawValue
        self.decorationStageRaw = DecorationStage.none.rawValue
        self.memories = []
    }
}
