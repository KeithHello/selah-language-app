import Foundation

/// Predefined sprite memories (小豆的回憶).
/// ~30 memories organized into 5 categories.
/// These are created during companion initialization and unlocked
/// progressively as the user achieves learning milestones.
enum SpriteMemoryPresets {

    static func all(for companionID: UUID) -> [SpriteMemory] {
        return startedMemories(companionID) +
               heardMemories(companionID) +
               deconstructedMemories(companionID) +
               spokenMemories(companionID) +
               becomingMemories(companionID)
    }

    // MARK: - 開始了 (6 memories)

    private static func startedMemories(_ id: UUID) -> [SpriteMemory] {
        [
            SpriteMemory(
                companionID: id,
                memoryKey: "first_app_open",
                title: "第一次睜開眼",
                descriptionText: "那一天你打開了 Selah，小豆從一顆小種子裡探出頭來。",
                icon: "🌱",
                category: .started
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_name",
                title: "你幫我取了名字",
                descriptionText: "這是我做為你的精靈的第一天。",
                icon: "✨",
                category: .started
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_seed_sentence",
                title: "第一句種子句",
                descriptionText: "你還記得自己選的第一句嗎？它現在已經變成你的一部分了。",
                icon: "🌿",
                category: .started
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_own_sentence",
                title: "第一次說出自己的句子",
                descriptionText: "你今天不是複製別人的話，是真的說了一句自己的英文。",
                icon: "💫",
                category: .started
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "day_7",
                title: "滿一週了",
                descriptionText: "不知不覺，我們在一起一週了。你比七天前多說了好多自己的句子。",
                icon: "🎂",
                category: .started
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "day_30",
                title: "滿一個月",
                descriptionText: "一個月了！小豆的葉子也長了，但最開心的是看到你越來越敢開口。",
                icon: "🌳",
                category: .started
            ),
        ]
    }

    // MARK: - 聽懂了 (6 memories)

    private static func heardMemories(_ id: UUID) -> [SpriteMemory] {
        [
            SpriteMemory(
                companionID: id,
                memoryKey: "first_listen",
                title: "第一次閉眼聆聽",
                descriptionText: "你沒有急著看英文，真的閉上眼睛聽了三遍。",
                icon: "👂",
                category: .heard
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_blind_guess_correct",
                title: "第一次盲聽猜對",
                descriptionText: "完全沒有看英文，你居然猜對了！耳朵開始進步了。",
                icon: "🎯",
                category: .heard
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "listen_streak_5",
                title: "連續五句聽完",
                descriptionText: "你一口氣聽完了五句，小豆在旁邊偷偷很開心。",
                icon: "🎧",
                category: .heard
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "late_night_listen",
                title: "深夜還在聽",
                descriptionText: "已經很晚了，你還想再聽一句。明天見也沒關係的。",
                icon: "🌙",
                category: .heard
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "speed_up_listen",
                title: "第一次加速聽",
                descriptionText: "今天你把速度調到 1.0x 了！耳朵越來越習慣英文的速度。",
                icon: "⚡",
                category: .heard
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "all_listen_complete",
                title: "今天所有聆聽都完成了",
                descriptionText: "今天的每一句都認真聽完了。耳朵今天辛苦了。",
                icon: "🏆",
                category: .heard
            ),
        ]
    }

    // MARK: - 拆開來懂 (6 memories)

    private static func deconstructedMemories(_ id: UUID) -> [SpriteMemory] {
        [
            SpriteMemory(
                companionID: id,
                memoryKey: "first_deconstruct",
                title: "第一次看拆解",
                descriptionText: "你認真看了那個詞組是怎麼用的，不只是背單字。",
                icon: "🔍",
                category: .deconstructed
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "added_first_vocab",
                title: "主動加了一個生詞",
                descriptionText: "你不是被系統塞的，是真的自己想記住這個詞。",
                icon: "📝",
                category: .deconstructed
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "vocab_no_longer_needed",
                title: "一個詞不再需要拆解了",
                descriptionText: "曾經需要提示的詞，現在你看到就直接懂了。",
                icon: "👍",
                category: .deconstructed
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "pattern_discovered",
                title: "發現了一個句型模式",
                descriptionText: "不是一個詞，是一個可以套用的說法。這個發現很有用！",
                icon: "💡",
                category: .deconstructed
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "sentence_from_hard_to_easy",
                title: "這句以前很難，現在一下就懂了",
                descriptionText: "同一句話回到眼前，你連拆解都不用看就懂了。",
                icon: "🔄",
                category: .deconstructed
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "vocab_re_added",
                title: "一個熟悉的詞回來找你",
                descriptionText: "沒關係的，有時候就是會卡住。它會再陪你到變熟為止。",
                icon: "🤗",
                category: .deconstructed
            ),
        ]
    }

    // MARK: - 說出口了 (6 memories)

    private static func spokenMemories(_ id: UUID) -> [SpriteMemory] {
        [
            SpriteMemory(
                companionID: id,
                memoryKey: "first_shadow",
                title: "第一次跟讀",
                descriptionText: "你真的看著英文說出口了。不是默念，是真的用了嘴巴和聲音。",
                icon: "🗣️",
                category: .spoken
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_practice_all_correct",
                title: "一組練習全部記得",
                descriptionText: "連續三張翻卡，全部都是「記得很清楚」。",
                icon: "✅",
                category: .spoken
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "used_vocab_in_new_sentence",
                title: "把學過的詞真的拿來用了",
                descriptionText: "在今天的句子裡，你自然用出了之前拆解過的詞。這就是學會了！",
                icon: "🎉",
                category: .spoken
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "first_self_recording",
                title: "第一次錄下自己的聲音",
                descriptionText: "聽到自己的聲音說英文，感覺不太一樣對吧？但這就是開始。",
                icon: "🎙️",
                category: .spoken
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "sentence_from_card_to_smooth",
                title: "這句從卡卡變順了",
                descriptionText: "以前拿到這句會卡住，今天連想都沒想就說出來了。",
                icon: "🌈",
                category: .spoken
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "weekend_practice",
                title: "週末也來練習了",
                descriptionText: "今天明明可以休息，你還是打開了 Selah。小豆好感動。",
                icon: "💪",
                category: .spoken
            ),
        ]
    }

    // MARK: - 越來越像自己 (6 memories)

    private static func becomingMemories(_ id: UUID) -> [SpriteMemory] {
        [
            SpriteMemory(
                companionID: id,
                memoryKey: "longest_sentence",
                title: "你說了最長的一句",
                descriptionText: "今天的句子比以前長了很多，裡面的想法也越來越完整。",
                icon: "📏",
                category: .becomingYou
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "covered_all_categories",
                title: "六個場景都說過了",
                descriptionText: "工作、朋友、吐槽、心裡話、想法、生活，你全部都用英文說過了。",
                icon: "🗺️",
                category: .becomingYou
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "emotional_sentence",
                title: "說了一句真心話",
                descriptionText: "今天的句子不只是練習，是真的想說的話。",
                icon: "❤️",
                category: .becomingYou
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "sentence_used_in_real_life",
                title: "在外面真的用出來了",
                descriptionText: "今天在真實生活中說出了學過的句子！這比任何練習都有用。",
                icon: "🌟",
                category: .becomingYou
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "revisited_old_sentence",
                title: "翻回去看了以前的句子",
                descriptionText: "你回到了以前的筆記，看到了自己剛開始學的樣子。",
                icon: "📖",
                category: .becomingYou
            ),
            SpriteMemory(
                companionID: id,
                memoryKey: "sprout_to_bloom",
                title: "小豆開花了",
                descriptionText: "兩週了！小豆頭上的花苞終於開了。跟你一樣，慢慢在長。",
                icon: "🌸",
                category: .becomingYou
            ),
        ]
    }

    /// Keys that should be unlocked on specific events.
    /// Returns the memory key if a matching condition is met.
    enum Trigger {
        case appOpen(count: Int)
        case listenCompleted(count: Int)
        case blindGuessCorrect
        case practiceAllCorrect
        case vocabUsed(count: Int)
        case sentenceCount(count: Int)
        case dayMilestone(days: Int)
        case allCategoriesCovered
    }

    static func key(for trigger: Trigger) -> String? {
        switch trigger {
        case .appOpen(let count):
            if count == 1 { return "first_app_open" }
            return nil
        case .listenCompleted(let count):
            if count == 1 { return "first_listen" }
            if count == 5 { return "listen_streak_5" }
            return nil
        case .blindGuessCorrect:
            return "first_blind_guess_correct"
        case .practiceAllCorrect:
            return "first_practice_all_correct"
        case .vocabUsed(let count):
            if count == 1 { return "used_vocab_in_new_sentence" }
            return nil
        case .sentenceCount(let count):
            if count == 1 { return "first_own_sentence" }
            if count == 30 { return "longest_sentence" }
            return nil
        case .dayMilestone(let days):
            if days == 7 { return "day_7" }
            if days == 14 { return "sprout_to_bloom" }
            if days == 30 { return "day_30" }
            return nil
        case .allCategoriesCovered:
            return "covered_all_categories"
        }
    }
}
