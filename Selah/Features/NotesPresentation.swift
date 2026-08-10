import Foundation

struct NotesSummary: Equatable {
    let total: Int
    let mastered: Int
}

enum NotesPresentation {
    static func summary(sentences: [Sentence]) -> NotesSummary {
        let active = sentences.filter { !$0.archived }
        let mastered = active.filter {
            guard let state = $0.reviewState?.state else { return false }
            return state == .familiar || state == .quiet
        }.count
        return NotesSummary(total: active.count, mastered: mastered)
    }

    static func visibleSentences(
        _ sentences: [Sentence],
        category: SentenceCategory?
    ) -> [Sentence] {
        sentences.filter { sentence in
            !sentence.archived && (category == nil || sentence.category == category)
        }
    }

    static func visibleMemories(_ memories: [SpriteMemory]) -> [SpriteMemory] {
        memories.filter(\.unlocked)
    }
}
