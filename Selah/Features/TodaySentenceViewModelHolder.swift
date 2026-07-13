import Foundation
import SwiftUI
import SwiftData

/// Holder for TodaySentenceViewModel to allow lazy initialization with injected services.
@MainActor
final class TodaySentenceViewModelHolder: ObservableObject {
    @Published var viewModel: TodaySentenceViewModel?

    func setup(
        speechService: SpeechRecognitionService,
        sentenceService: SentenceGenerationService,
        audioService: AudioGenerationService,
        modelContext: ModelContext,
        connectivity: any ConnectivityProviding = ConnectivityMonitor(initialStatus: .online),
        generationRetryQueue: (any GenerationRetryQueue)? = nil,
        defaultVoiceProfile: VoiceProfile = .gentleNatural
    ) {
        guard viewModel == nil else { return }
        viewModel = TodaySentenceViewModel(
            speechService: speechService,
            sentenceService: sentenceService,
            audioService: audioService,
            modelContext: modelContext,
            connectivity: connectivity,
            generationRetryQueue: generationRetryQueue,
            defaultVoiceProfile: defaultVoiceProfile
        )
    }
}
