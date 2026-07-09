import Foundation
import SwiftData

/// Sprite memory — a learning milestone recorded from the companion's
/// perspective. These are the "小豆的回憶" items shown in Notes.
/// ~24-30 memories defined; unlocked progressively.
@Model
final class SpriteMemory {
    @Attribute(.unique) var id: UUID

    var companionID: UUID
    var memoryKey: String             // unique key for lookup
    var title: String                 // e.g. "第一次盲聽猜對"
    var descriptionText: String       // warm narrative from sprite's perspective
    var icon: String                  // emoji or symbol
    var unlocked: Bool
    var unlockedAt: Date?
    var categoryRaw: String           // memory category for grouping

    /// Memory categories for grouping in Notes.
    enum Category: String, CaseIterable {
        case started = "開始了"
        case heard = "聽懂了"
        case deconstructed = "拆開來懂"
        case spoken = "說出口了"
        case becomingYou = "越來越像自己"
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .started }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        companionID: UUID,
        memoryKey: String,
        title: String,
        descriptionText: String,
        icon: String,
        category: Category = .started
    ) {
        self.id = id
        self.companionID = companionID
        self.memoryKey = memoryKey
        self.title = title
        self.descriptionText = descriptionText
        self.icon = icon
        self.unlocked = false
        self.categoryRaw = category.rawValue
    }

    func unlock() {
        unlocked = true
        unlockedAt = Date()
    }
}
