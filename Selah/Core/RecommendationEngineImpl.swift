import Foundation

/// On-device recommendation engine.
/// Rules based on v8 unified design spec §5.
actor RecommendationEngineImpl: RecommendationEngine {

    private let sentenceRepo: SentenceRepository
    private let reviewScheduler: ReviewScheduler

    init(sentenceRepo: SentenceRepository, reviewScheduler: ReviewScheduler) {
        self.sentenceRepo = sentenceRepo
        self.reviewScheduler = reviewScheduler
    }

    /// Compute the best next action. State-first, time-assisted.
    ///
    /// Priority order:
    /// 1. practiceReady exists → Practice
    /// 2. previewedNotListened exists → Listen
    /// 3. evening + previewReady exists → Night Preview
    /// 4. todaySentenceMissing or contentPoolLow → Today Sentence
    /// 5. fallback → Seed Listen
    func recommendNextAction(now: Date) async throws -> TodayRecommendation {
        let isEvening = isEveningHour(now)
        let isLateNight = isLateNightHour(now)

        // 1. Practice-ready sentences
        let practiceReady = try await reviewScheduler.dueForPractice(limit: 3)
        if !practiceReady.isEmpty && !isLateNight {
            return makeRecommendation(
                type: .practice,
                count: practiceReady.count,
                sentences: practiceReady,
                nextState: "現在"
            )
        }

        // 2. Previewed-but-not-listened
        let toListen = try await reviewScheduler.suitableForListen(limit: 3)
        let previewedNotListened = toListen.filter { $0.isPreviewedNotListened }
        if !previewedNotListened.isEmpty {
            return makeRecommendation(
                type: .listen,
                count: previewedNotListened.count,
                sentences: Array(previewedNotListened),
                plainReason: "昨晚看過了，等你聽一次",
                nextState: "現在"
            )
        }

        // 3. Evening + preview-ready
        if isEvening {
            let previewReady = try await reviewScheduler.suitableForPreview(limit: 5)
            if !previewReady.isEmpty {
                return makeRecommendation(
                    type: .nightPreview,
                    count: previewReady.count,
                    sentences: previewReady,
                    plainReason: "先看一眼就好，明天聽起來會更輕鬆",
                    nextState: "今晚"
                )
            }
        }

        // 4. Content pool low or no sentence today
        let hasCreatedToday = try await reviewScheduler.hasCreatedSentenceToday()
        let isPoolLow = try await reviewScheduler.isContentPoolLow()
        if !hasCreatedToday || isPoolLow {
            return TodayRecommendation(
                type: .todaySentence,
                reason: TodayRecommendationType.todaySentence.reasonTemplate,
                sentenceCount: 1,
                reasonItems: [
                    TodayRecommendation.ReasonItem(
                        id: UUID(),
                        sentencePreview: "新的中文句子",
                        nextState: "現在",
                        plainReason: "它會變成之後會聽、會練的英文"
                    )
                ]
            )
        }

        // 5. Fallback: seed listen
        let allListenable = toListen
        return makeRecommendation(
            type: .seedListen,
            count: min(allListenable.count, 3),
            sentences: allListenable,
            plainReason: "先聽聽這幾句，之後會有你專屬的句子",
            nextState: "現在"
        )
    }

    func buildContextualBridge(after event: LearningEvent) async throws -> ContextualBridge? {
        switch event.eventType {
        case .listenCompleted:
            // After listen, offer practice if useful
            let practiceReady = try await reviewScheduler.dueForPractice(limit: 3)
            if !practiceReady.isEmpty {
                return ContextualBridge(
                    suggestion: .practice(practiceReady.count)
                )
            }
            return ContextualBridge(suggestion: .listenMore(3))

        case .practiceRated:
            return ContextualBridge(suggestion: .stop)

        case .previewCompleted:
            return ContextualBridge(suggestion: .stop)

        case .sentenceCreated:
            // After creating a sentence, offer to create another
            return ContextualBridge(suggestion: .recordAnother)

        default:
            return nil
        }
    }

    // MARK: - Private Helpers

    private func isEveningHour(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 18
    }

    private func isLateNightHour(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 6
    }

    private func makeRecommendation(
        type: TodayRecommendationType,
        count: Int,
        sentences: [Sentence],
        plainReason: String? = nil,
        nextState: String = "現在"
    ) -> TodayRecommendation {
        let reason = plainReason ?? type.reasonTemplate
        let items = sentences.prefix(3).map { sentence in
            TodayRecommendation.ReasonItem(
                id: sentence.id,
                sentencePreview: sentence.sourceText,
                nextState: nextState,
                plainReason: reason
            )
        }

        return TodayRecommendation(
            type: type,
            reason: "有 \(count) 句\(reason)",
            sentenceCount: count,
            reasonItems: items
        )
    }
}
