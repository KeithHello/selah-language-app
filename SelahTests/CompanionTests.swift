import XCTest
@testable import Selah

/// Tests for the Companion model's sprite logic.
/// Covers: initialization, mood transitions, decoration stages,
/// and day count calculations.
final class CompanionTests: XCTestCase {

    func testCompanionInitialization() {
        let companion = Companion(displayName: "小豆")

        XCTAssertEqual(companion.displayName, "小豆")
        XCTAssertTrue(companion.active)
        XCTAssertEqual(companion.companionKey, .seedSprite)
        XCTAssertEqual(companion.mood, .neutral)
        XCTAssertEqual(companion.decorationStage, .none)
        XCTAssertTrue(companion.memories.isEmpty)
        XCTAssertNil(companion.lastInteractionAt)
    }

    func testCompanionCustomKey() {
        let companion = Companion(
            companionKey: .seedSprite,
            displayName: "Test"
        )
        XCTAssertEqual(companion.companionKey, .seedSprite)
    }

    // MARK: - Mood updates

    func testUpdateMoodHappy() {
        let companion = Companion(displayName: "Test")
        companion.updateMood(daysSinceLastInteraction: 0)
        XCTAssertEqual(companion.mood, .happy)

        companion.updateMood(daysSinceLastInteraction: 1)
        XCTAssertEqual(companion.mood, .happy)

        companion.updateMood(daysSinceLastInteraction: 2)
        XCTAssertEqual(companion.mood, .happy)
    }

    func testUpdateMoodNeutral() {
        let companion = Companion(displayName: "Test")
        companion.updateMood(daysSinceLastInteraction: 3)
        XCTAssertEqual(companion.mood, .neutral)

        companion.updateMood(daysSinceLastInteraction: 5)
        XCTAssertEqual(companion.mood, .neutral)

        companion.updateMood(daysSinceLastInteraction: 6)
        XCTAssertEqual(companion.mood, .neutral)
    }

    func testUpdateMoodQuiet() {
        let companion = Companion(displayName: "Test")
        companion.updateMood(daysSinceLastInteraction: 7)
        XCTAssertEqual(companion.mood, .quiet)

        companion.updateMood(daysSinceLastInteraction: 30)
        XCTAssertEqual(companion.mood, .quiet)
    }

    // MARK: - Decoration stages

    func testUpdateDecorationForDay0() {
        let companion = Companion(displayName: "Test")
        // Force acquiredAt to today
        companion.acquiredAt = Date()
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .none)
    }

    func testUpdateDecorationForDay4() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .sprout)
    }

    func testUpdateDecorationForDay7() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .leaf)
    }

    func testUpdateDecorationForDay10() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .bud)
    }

    func testUpdateDecorationForDay14() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .bloom)
    }

    func testUpdateDecorationForDay100() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        companion.updateDecoration()
        XCTAssertEqual(companion.decorationStage, .bloom)
    }

    // MARK: - Days since acquired

    func testDaysSinceAcquiredDay0() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Date()
        XCTAssertEqual(companion.daysSinceAcquired, 0)
    }

    func testDaysSinceAcquiredDay7() {
        let companion = Companion(displayName: "Test")
        companion.acquiredAt = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        // Allow ±1 for timezone edge cases
        let days = companion.daysSinceAcquired
        XCTAssertTrue(days == 7 || days == 6 || days == 8)
    }
}

/// Tests for the SpriteMemory model.
final class SpriteMemoryTests: XCTestCase {

    func testSpriteMemoryInitialization() {
        let companionID = UUID()
        let memory = SpriteMemory(
            companionID: companionID,
            memoryKey: "first_app_open",
            title: "第一次睜開眼",
            descriptionText: "那一天你打開了 Selah。",
            icon: "🌱",
            category: .started
        )

        XCTAssertEqual(memory.companionID, companionID)
        XCTAssertEqual(memory.memoryKey, "first_app_open")
        XCTAssertEqual(memory.title, "第一次睜開眼")
        XCTAssertEqual(memory.descriptionText, "那一天你打開了 Selah。")
        XCTAssertEqual(memory.icon, "🌱")
        XCTAssertEqual(memory.category, .started)
        XCTAssertFalse(memory.unlocked)
        XCTAssertNil(memory.unlockedAt)
    }

    func testSpriteMemoryDefaultCategory() {
        let memory = SpriteMemory(
            companionID: UUID(),
            memoryKey: "test",
            title: "Test",
            descriptionText: "Test",
            icon: "🌟"
        )
        XCTAssertEqual(memory.category, .started)
    }

    func testSpriteMemoryUnlock() {
        let memory = SpriteMemory(
            companionID: UUID(),
            memoryKey: "test",
            title: "Test",
            descriptionText: "Test",
            icon: "🌟"
        )

        XCTAssertFalse(memory.unlocked)

        memory.unlock()
        XCTAssertTrue(memory.unlocked)
        XCTAssertNotNil(memory.unlockedAt)
    }

    func testSpriteMemoryCategoryAllCases() {
        XCTAssertEqual(SpriteMemory.Category.allCases.count, 5)
        XCTAssertEqual(SpriteMemory.Category.started.rawValue, "開始了")
        XCTAssertEqual(SpriteMemory.Category.heard.rawValue, "聽懂了")
        XCTAssertEqual(SpriteMemory.Category.deconstructed.rawValue, "拆開來懂")
        XCTAssertEqual(SpriteMemory.Category.spoken.rawValue, "說出口了")
        XCTAssertEqual(SpriteMemory.Category.becomingYou.rawValue, "越來越像自己")
    }
}

/// Tests for the SpriteMemoryPresets enum.
final class SpriteMemoryPresetsTests: XCTestCase {

    func testAllMemoriesCount() {
        let companionID = UUID()
        let memories = SpriteMemoryPresets.all(for: companionID)
        XCTAssertEqual(memories.count, 30)
    }

    func testAllMemoriesHaveUniqueKeys() {
        let companionID = UUID()
        let memories = SpriteMemoryPresets.all(for: companionID)
        let keys = Set(memories.map { $0.memoryKey })
        XCTAssertEqual(keys.count, 30)
    }

    func testAllMemoriesBelongToCompanion() {
        let companionID = UUID()
        let memories = SpriteMemoryPresets.all(for: companionID)
        XCTAssertTrue(memories.allSatisfy { $0.companionID == companionID })
    }

    func testAllMemoriesStartLocked() {
        let companionID = UUID()
        let memories = SpriteMemoryPresets.all(for: companionID)
        XCTAssertTrue(memories.allSatisfy { !$0.unlocked })
    }

    func testMemoryCategoryDistribution() {
        let companionID = UUID()
        let memories = SpriteMemoryPresets.all(for: companionID)

        let started = memories.filter { $0.category == .started }
        let heard = memories.filter { $0.category == .heard }
        let deconstructed = memories.filter { $0.category == .deconstructed }
        let spoken = memories.filter { $0.category == .spoken }
        let becomingYou = memories.filter { $0.category == .becomingYou }

        XCTAssertEqual(started.count, 6)
        XCTAssertEqual(heard.count, 6)
        XCTAssertEqual(deconstructed.count, 6)
        XCTAssertEqual(spoken.count, 6)
        XCTAssertEqual(becomingYou.count, 6)
    }

    // MARK: - Trigger to key mapping

    func testTriggerAppOpenCount1() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .appOpen(count: 1)), "first_app_open")
        XCTAssertNil(SpriteMemoryPresets.key(for: .appOpen(count: 2)))
        XCTAssertNil(SpriteMemoryPresets.key(for: .appOpen(count: 0)))
    }

    func testTriggerListenCompletedCount1() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .listenCompleted(count: 1)), "first_listen")
    }

    func testTriggerListenCompletedCount5() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .listenCompleted(count: 5)), "listen_streak_5")
    }

    func testTriggerListenCompletedOtherCounts() {
        XCTAssertNil(SpriteMemoryPresets.key(for: .listenCompleted(count: 0)))
        XCTAssertNil(SpriteMemoryPresets.key(for: .listenCompleted(count: 3)))
    }

    func testTriggerBlindGuessCorrect() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .blindGuessCorrect), "first_blind_guess_correct")
    }

    func testTriggerPracticeAllCorrect() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .practiceAllCorrect), "first_practice_all_correct")
    }

    func testTriggerVocabUsedCount1() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .vocabUsed(count: 1)), "used_vocab_in_new_sentence")
        XCTAssertNil(SpriteMemoryPresets.key(for: .vocabUsed(count: 0)))
        XCTAssertNil(SpriteMemoryPresets.key(for: .vocabUsed(count: 2)))
    }

    func testTriggerSentenceCount1() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .sentenceCount(count: 1)), "first_own_sentence")
    }

    func testTriggerSentenceCount30() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .sentenceCount(count: 30)), "longest_sentence")
        XCTAssertNil(SpriteMemoryPresets.key(for: .sentenceCount(count: 10)))
    }

    func testTriggerDayMilestone7() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .dayMilestone(days: 7)), "day_7")
    }

    func testTriggerDayMilestone14() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .dayMilestone(days: 14)), "sprout_to_bloom")
    }

    func testTriggerDayMilestone30() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .dayMilestone(days: 30)), "day_30")
    }

    func testTriggerDayMilestoneOther() {
        XCTAssertNil(SpriteMemoryPresets.key(for: .dayMilestone(days: 5)))
        XCTAssertNil(SpriteMemoryPresets.key(for: .dayMilestone(days: 20)))
    }

    func testTriggerAllCategoriesCovered() {
        XCTAssertEqual(SpriteMemoryPresets.key(for: .allCategoriesCovered), "covered_all_categories")
    }
}
