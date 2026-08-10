import Foundation

/// Review scheduler for spaced repetition.
/// Operates only on internal state; nothing is shown to users.
protocol ReviewScheduler {
    /// Mark a sentence as listened to. Moves from new → learning.
    func updateAfterListen(sentenceID: UUID, at date: Date) async throws

    /// Apply a practice recall signal and update review timing.
    func updateAfterPractice(
        sentenceID: UUID,
        signal: RecallSignal,
        at date: Date
    ) async throws

    /// Get sentences due for Practice, sorted by priority.
    /// Prefers `learning` sentences, then `familiar`.
    func dueForPractice(limit: Int) async throws -> [Sentence]

    /// Get sentences suitable for Listen.
    /// Includes previewed-but-not-listened and recently-failed sentences.
    func suitableForListen(limit: Int) async throws -> [Sentence]

    /// Get sentences suitable for Night Preview.
    func suitableForPreview(limit: Int) async throws -> [Sentence]

    /// Persist completion of a Night Preview session and its learning event.
    func markPreviewed(sentenceIDs: [UUID], at date: Date) async throws

    /// Check if there are enough personal sentences in the pool.
    func isContentPoolLow() async throws -> Bool

    /// Check if the user has created a sentence today.
    func hasCreatedSentenceToday() async throws -> Bool
}
