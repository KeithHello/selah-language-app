import Foundation

/// Six content categories for sentence classification.
/// Used internally for topic grouping and content tracking.
enum SentenceCategory: String, Codable, CaseIterable {
    case work = "work"
    case friends = "friends"
    case vent = "vent"
    case heartfelt = "heartfelt"
    case debate = "debate"
    case dailyLife = "daily_life"

    var displayName: String {
        switch self {
        case .work:       return "工作的事"
        case .friends:    return "朋友之間"
        case .vent:       return "想吐槽的"
        case .heartfelt:  return "心裡話"
        case .debate:     return "我的想法"
        case .dailyLife:  return "生活日常"
        }
    }

    var emoji: String {
        switch self {
        case .work:       return "💼"
        case .friends:    return "💬"
        case .vent:       return "💨"
        case .heartfelt:  return "💕"
        case .debate:     return "🗣️"
        case .dailyLife:  return "🌍"
        }
    }
}

/// Internal vocabulary help state. Never shown to users directly.
/// User-facing display collapses these into two groups:
///   new/learning → "仍在關注"
///   familiar/owned → "已比較熟"
enum VocabHelpState: String, Codable {
    case new
    case learning
    case familiar
    case owned

    var userFacingGroup: String {
        switch self {
        case .new, .learning: return "仍在關注"
        case .familiar, .owned: return "已比較熟"
        }
    }
}

/// Internal review state for sentence scheduling.
/// Never exposed to users. Replaces the retired Smart Excel L0-L5 system.
enum ReviewStateValue: String, Codable {
    case new
    case learning
    case familiar
    case quiet

    /// Next review interval in days after a recall signal.
    func nextInterval(after signal: RecallSignal) -> Int {
        switch (self, signal) {
        case (.new, .clear):     return 1
        case (.new, .almost):    return 1
        case (.new, .failed):    return 1
        case (.learning, .clear):    return 3
        case (.learning, .almost):   return 1
        case (.learning, .failed):   return 1
        case (.familiar, .clear):    return 7
        case (.familiar, .almost):   return 1
        case (.familiar, .failed):   return 1
        case (.quiet, .clear):       return 30
        case (.quiet, .almost):      return 1
        case (.quiet, .failed):      return 1
        }
    }

    /// Next state after a recall signal.
    func nextState(after signal: RecallSignal) -> ReviewStateValue {
        switch (self, signal) {
        case (.new, _):                return .learning
        case (.learning, .clear):      return .familiar
        case (.learning, .almost):     return .learning
        case (.learning, .failed):     return .learning
        case (.familiar, .clear):      return .quiet
        case (.familiar, .almost):     return .learning
        case (.familiar, .failed):     return .learning
        case (.quiet, .clear):         return .quiet
        case (.quiet, .almost):        return .learning
        case (.quiet, .failed):        return .learning
        }
    }
}

/// User self-rating after Practice recall.
enum RecallSignal: String, Codable {
    case clear   // 「記得很清楚」
    case almost  // 「差一點」
    case failed  // 「完全不會」
}

/// Sentence origin: user-recorded or system seed.
enum SentenceOrigin: String, Codable {
    case userRecording = "user_recording"
    case systemSeed = "system_seed"
}

/// Audio generation status for an AudioAsset.
enum AudioGenerationStatus: String, Codable {
    case queued
    case generating
    case ready
    case failed
}

/// Reason for audio generation request.
enum AudioGenerationReason: String, Codable {
    case initialGeneration = "initial_generation"
    case manualRegeneration = "manual_regeneration"
    case voiceChangedRegeneration = "voice_changed_regeneration"
}

/// Generation job type for the retry queue.
enum GenerationJobType: String, Codable {
    case sentenceGeneration = "sentence_generation"
    case audioGeneration = "audio_generation"
    case audioRegeneration = "audio_regeneration"
}

/// Generation job status.
enum GenerationJobStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

/// Sprite companion type identifier.
enum CompanionKey: String, Codable {
    case seedSprite = "seed_sprite"  // MVP: the only companion
}

/// Voice profile identifiers, mapped to backend TTS voices.
/// User-facing labels: 溫柔自然 / 清晰慢速 / 日常輕快
enum VoiceProfile: String, Codable, CaseIterable {
    case gentleNatural = "gentle-natural"
    case clearSlow = "clear-slow"
    case dailyBright = "daily-bright"

    var displayName: String {
        switch self {
        case .gentleNatural: return "溫柔自然"
        case .clearSlow:     return "清晰慢速"
        case .dailyBright:   return "日常輕快"
        }
    }

    var description: String {
        switch self {
        case .gentleNatural: return "速度適中，適合每天跟讀"
        case .clearSlow:     return "更慢一點，適合剛開始聽"
        case .dailyBright:   return "比較像朋友說話的速度"
        }
    }
}

/// Supported source languages.
enum SourceLanguage: String, Codable {
    case zhHant = "zh-Hant"
}

/// Supported target languages. MVP: English only.
enum TargetLanguage: String, Codable {
    case en
    case ja  // future
}

/// Playback speed presets for audio.
enum PlaybackSpeed: Double, Codable, CaseIterable {
    case slow = 0.7
    case learning = 0.85
    case normal = 1.0
    case fast = 1.2

    var displayName: String {
        switch self {
        case .slow:     return "0.7x"
        case .learning: return "0.85x"
        case .normal:   return "1.0x"
        case .fast:     return "1.2x"
        }
    }

    /// Cycle to the next speed.
    func next() -> PlaybackSpeed {
        let all = PlaybackSpeed.allCases
        guard let idx = all.firstIndex(of: self) else { return .learning }
        return all[(idx + 1) % all.count]
    }
}

/// Learning event types for analytics and recommendation.
enum LearningEventType: String, Codable {
    case sentenceCreated = "sentence_created"
    case listenStarted = "listen_started"
    case listenCompleted = "listen_completed"
    case practiceStarted = "practice_started"
    case practiceRated = "practice_rated"
    case previewCompleted = "preview_completed"
    case vocabAdded = "vocab_added"
    case vocabRemoved = "vocab_removed"
    case voiceSelected = "voice_selected"
    case memoryUnlocked = "memory_unlocked"
}

/// Today's recommended next action type.
enum TodayRecommendationType: String {
    case practice
    case listen
    case nightPreview = "night_preview"
    case todaySentence = "today_sentence"
    case seedListen = "seed_listen"

    var displayName: String {
        switch self {
        case .practice:      return "練習"
        case .listen:        return "聆聽"
        case .nightPreview:  return "夜間預覽"
        case .todaySentence: return "今日一句"
        case .seedListen:    return "聆聽"
        }
    }

    var reasonTemplate: String {
        switch self {
        case .practice:      return "有幾句之前聽過，現在剛好可以回想一下。"
        case .listen:        return "這幾句已經有點熟了，現在讓耳朵接上。"
        case .nightPreview:  return "先看一眼就好，明天聽起來會更輕鬆。"
        case .todaySentence: return "它會變成之後會聽、會練的英文。"
        case .seedListen:    return "先聽聽這幾句，之後會有你專屬的句子。"
        }
    }
}

/// Sprite mood. Internal only, not a user-facing score.
enum SpriteMood: String, Codable {
    case happy    // recent learning activity
    case neutral  // normal
    case quiet    // extended absence
}

/// Sprite decoration stages, computed from day count.
enum DecorationStage: String, Codable, CaseIterable {
    case none
    case sprout   // Day 4+
    case leaf     // Day 7+
    case bud      // Day 10+
    case bloom    // Day 14+

    static func stage(for dayCount: Int) -> DecorationStage {
        switch dayCount {
        case 0..<4:  return .none
        case 4..<7:  return .sprout
        case 7..<10: return .leaf
        case 10..<14: return .bud
        default:     return .bloom
        }
    }
}
