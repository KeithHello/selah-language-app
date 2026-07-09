import Foundation

/// Mock sentence generation service for prototyping.
/// Returns realistic English translations with simulated delay.
actor MockSentenceGenerationService: SentenceGenerationService {

    private let mockDelay: UInt64 = 1_500_000_000  // 1.5 seconds

    /// Pre-defined mock translations keyed by Chinese text prefix.
    private let mockDatabase: [(zh: String, en: String, category: SentenceCategory, vocab: [VocabCandidate], deconstruction: [DeconstructionItem])] = [
        (
            zh: "今天工作忙翻了，但還是準時下班了",
            en: "I was swamped at work today, but I still got off on time.",
            category: .work,
            vocab: [
                VocabCandidate(surfaceText: "swamped", meaningInContext: "忙翻了", suggestedHelpState: .learning),
                VocabCandidate(surfaceText: "got off on time", meaningInContext: "準時下班", suggestedHelpState: .new),
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "swamped", meaning: "忙翻了、忙到不行", type: .phrase),
                DeconstructionItem(surfaceText: "got off on time", meaning: "準時下班", type: .phrase),
            ]
        ),
        (
            zh: "同事說的笑話一點都不好笑",
            en: "My coworker's joke wasn't funny at all.",
            category: .friends,
            vocab: [
                VocabCandidate(surfaceText: "wasn't funny at all", meaningInContext: "一點都不好笑", suggestedHelpState: .learning),
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "wasn't ... at all", meaning: "一點都不……", type: .pattern),
                DeconstructionItem(surfaceText: "wasn't funny at all", meaning: "一點都不好笑", type: .phrase),
            ]
        ),
        (
            zh: "我真的受不了這個天氣了",
            en: "I seriously can't take this weather anymore.",
            category: .vent,
            vocab: [
                VocabCandidate(surfaceText: "can't take this ... anymore", meaningInContext: "受不了這個……了", suggestedHelpState: .learning),
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "seriously", meaning: "真的、認真的", type: .phrase),
                DeconstructionItem(surfaceText: "can't take ... anymore", meaning: "再也受不了……", type: .pattern),
            ]
        ),
        (
            zh: "我今天想吃拉麵",
            en: "I'm in the mood for ramen today.",
            category: .dailyLife,
            vocab: [
                VocabCandidate(surfaceText: "in the mood for", meaningInContext: "想吃、想要", suggestedHelpState: .learning),
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "in the mood for", meaning: "想要、想吃", type: .phrase),
            ]
        ),
    ]

    func generateSentence(
        sourceText: String,
        sourceLanguage: SourceLanguage,
        targetLanguage: TargetLanguage,
        categoryHint: SentenceCategory?
    ) async throws -> GeneratedSentenceResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: mockDelay)

        // Try to match an existing mock entry
        if let match = mockDatabase.first(where: { sourceText.contains($0.zh) || $0.zh.contains(sourceText) }) {
            return GeneratedSentenceResult(
                targetText: match.en,
                category: match.category,
                vocabulary: match.vocab,
                deconstruction: match.deconstruction,
                promptVersion: "v8.0-mock"
            )
        }

        // Fallback: generate a simple translation
        return GeneratedSentenceResult(
            targetText: "Here's a natural English version of what you said.",
            category: categoryHint ?? .dailyLife,
            vocabulary: [
                VocabCandidate(surfaceText: "natural", meaningInContext: "自然的", suggestedHelpState: .new),
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "natural", meaning: "自然的、口語的", type: .phrase),
            ],
            promptVersion: "v8.0-mock"
        )
    }
}
