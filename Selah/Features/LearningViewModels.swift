import SwiftUI
import SwiftData

/// ViewModel for TodayView, drives the smart recommendation card with real data.
@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var recommendation: TodayRecommendation?
    @Published private(set) var isLoading = false
    @Published private(set) var totalSentences = 0
    @Published private(set) var practicedSentences = 0

    private let engine: any RecommendationEngine
    private let modelContext: ModelContext

    init(engine: any RecommendationEngine, modelContext: ModelContext) {
        self.engine = engine
        self.modelContext = modelContext
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            recommendation = try await engine.recommendNextAction(now: Date())
            totalSentences = try modelContext.fetchCount(
                FetchDescriptor<Sentence>(predicate: #Predicate<Sentence> { !$0.archived })
            )
            practicedSentences = try modelContext.fetchCount(
                FetchDescriptor<Sentence>(predicate: #Predicate<Sentence> {
                    $0.listenCompletedAt != nil && !$0.archived
                })
            )
        } catch {
            recommendation = nil
            totalSentences = 0
            practicedSentences = 0
        }
    }
}

/// ViewModel holder that resolves AppState dependencies after SwiftUI environment injection.
@MainActor
final class TodayViewModelHolder: ObservableObject {
    @Published var viewModel: TodayViewModel?

    func setup(
        engine: (any RecommendationEngine)?,
        modelContext: ModelContext
    ) {
        guard viewModel == nil, let engine else { return }
        viewModel = TodayViewModel(engine: engine, modelContext: modelContext)
    }
}

/// ViewModel for PracticeView, loads real sentences that have been listened to.
@MainActor
final class PracticeViewModel: ObservableObject {
    struct PracticeCard: Identifiable {
        let id: UUID
        let zhText: String
        let enText: String
        let sentence: Sentence
    }

    @Published private(set) var cards: [PracticeCard] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isComplete = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let modelContext: ModelContext
    private let reviewScheduler: any ReviewScheduler
    private let memoryUnlockService: SpriteMemoryUnlockService?
    private let companionID: UUID?
    private var allRatingsClear = true

    init(
        modelContext: ModelContext,
        reviewScheduler: any ReviewScheduler,
        memoryUnlockService: SpriteMemoryUnlockService? = nil,
        companionID: UUID? = nil
    ) {
        self.modelContext = modelContext
        self.reviewScheduler = reviewScheduler
        self.memoryUnlockService = memoryUnlockService
        self.companionID = companionID
    }

    var currentCard: PracticeCard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let sentences = try await reviewScheduler.dueForPractice(limit: 10)
            cards = sentences.filter { $0.isPracticeReady }.map { sentence in
                PracticeCard(
                    id: sentence.id,
                    zhText: sentence.sourceText,
                    enText: sentence.targetText,
                    sentence: sentence
                )
            }
            currentIndex = 0
            allRatingsClear = true
            isComplete = cards.isEmpty == false ? false : true
        } catch {
            cards = []
            isComplete = false
            errorMessage = "暫時無法載入練習內容，請稍後再試。"
        }
    }

    func rate(signal: RecallSignal) {
        guard let card = currentCard else { return }
        let sentenceID = card.sentence.id
        allRatingsClear = allRatingsClear && signal == .clear
        let completesAllClearSession = currentIndex == cards.count - 1 && allRatingsClear

        Task {
            do {
                try await reviewScheduler.updateAfterPractice(
                    sentenceID: sentenceID,
                    signal: signal,
                    at: Date()
                )
                if completesAllClearSession, let memoryUnlockService, let companionID {
                    try memoryUnlockService.unlock(
                        for: .practiceAllCorrect,
                        companionID: companionID
                    )
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "這次回饋尚未保存，請稍後再試。"
                }
            }
        }

        if currentIndex < cards.count - 1 {
            currentIndex += 1
        } else {
            isComplete = true
        }
    }
}

/// ViewModel for NightPreviewView, loads real unpreviewed sentences.
@MainActor
final class NightPreviewViewModel: ObservableObject {
    struct PreviewItem: Identifiable {
        let id: UUID
        let enText: String
        let zhText: String
        let sentence: Sentence
    }

    @Published private(set) var items: [PreviewItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isComplete = false
    @Published private(set) var errorMessage: String?

    private let reviewScheduler: any ReviewScheduler

    init(reviewScheduler: any ReviewScheduler) {
        self.reviewScheduler = reviewScheduler
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let sentences = try await reviewScheduler.suitableForPreview(limit: 5)
            items = sentences.map { sentence in
                PreviewItem(
                    id: sentence.id,
                    enText: sentence.targetText,
                    zhText: sentence.sourceText,
                    sentence: sentence
                )
            }
            isComplete = items.isEmpty
        } catch {
            items = []
            isComplete = false
            errorMessage = "暫時無法載入夜間預覽，請稍後再試。"
        }
    }

    func markPreviewed() async {
        do {
            try await reviewScheduler.markPreviewed(
                sentenceIDs: items.map(\.id),
                at: Date()
            )
            isComplete = true
        } catch {
            errorMessage = "這次預覽進度尚未保存，請稍後再試。"
        }
    }
}

@MainActor
final class PracticeViewModelHolder: ObservableObject {
    @Published var viewModel: PracticeViewModel?

    func setup(
        modelContext: ModelContext,
        reviewScheduler: (any ReviewScheduler)?,
        memoryUnlockService: SpriteMemoryUnlockService? = nil,
        companionID: UUID? = nil
    ) {
        guard viewModel == nil, let reviewScheduler else { return }
        viewModel = PracticeViewModel(
            modelContext: modelContext,
            reviewScheduler: reviewScheduler,
            memoryUnlockService: memoryUnlockService,
            companionID: companionID
        )
    }
}

@MainActor
final class NightPreviewViewModelHolder: ObservableObject {
    @Published var viewModel: NightPreviewViewModel?

    func setup(reviewScheduler: (any ReviewScheduler)?) {
        guard viewModel == nil, let reviewScheduler else { return }
        viewModel = NightPreviewViewModel(reviewScheduler: reviewScheduler)
    }
}
