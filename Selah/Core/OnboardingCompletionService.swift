import Foundation
import SwiftData

struct OnboardingSeedPreset: Identifiable, Equatable {
    let id: String
    let sourceText: String
    let targetText: String
    let category: SentenceCategory

    static let defaults = [
        OnboardingSeedPreset(
            id: "onboarding-daily",
            sourceText: "今天過得怎麼樣？",
            targetText: "How was your day?",
            category: .dailyLife
        ),
        OnboardingSeedPreset(
            id: "onboarding-work",
            sourceText: "工作好累，但還是完成了。",
            targetText: "Work was exhausting, but I still got it done.",
            category: .work
        ),
        OnboardingSeedPreset(
            id: "onboarding-friends",
            sourceText: "想約朋友一起吃飯。",
            targetText: "I want to ask my friends out for a meal.",
            category: .friends
        ),
    ]
}

@MainActor
final class OnboardingCompletionService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func complete(
        companionName: String,
        selectedSeeds: [OnboardingSeedPreset],
        companion: Companion,
        preference: UserPreference,
        now: Date = Date()
    ) throws {
        let trimmedName = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        companion.displayName = trimmedName
        preference.activeCompanionID = companion.id
        preference.onboardingCompleted = true
        preference.updatedAt = now

        let existingSeeds = try modelContext.fetch(FetchDescriptor<Sentence>())
            .filter { $0.origin == .systemSeed }
        let existingSourceTexts = Set(existingSeeds.map(\.sourceText))

        for seed in selectedSeeds where !existingSourceTexts.contains(seed.sourceText) {
            modelContext.insert(
                Sentence(
                    sourceText: seed.sourceText,
                    targetText: seed.targetText,
                    category: seed.category,
                    origin: .systemSeed
                )
            )
        }
        try modelContext.save()
    }
}
