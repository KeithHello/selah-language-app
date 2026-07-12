import SwiftUI
import SwiftData

@main
struct SelahApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isLoading {
                LaunchScreen()
                    .task {
                        await appState.initialize()
                    }
            } else if !appState.preferences.onboardingCompleted {
                OnboardingView()
                    .environmentObject(appState)
            } else {
                MainTabView()
                    .environmentObject(appState)
            }
        }
        .modelContainer(appState.modelContainer)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var preferences = UserPreference.default()
    @Published var activeCompanion: Companion?
    @Published var showToast: ToastInfo?

    let modelContainer: ModelContainer

    // Services (injected, initialized during `initialize()`)
    var sentenceGenService: (any SentenceGenerationService)?
    var audioGenService: (any AudioGenerationService)?
    var speechService: (any SpeechRecognitionService)?
    var recommendationEngine: (any RecommendationEngine)?
    var reviewScheduler: (any ReviewScheduler)?
    var vocabularyHelp: VocabularyHelpUseCaseImpl?

    struct ToastInfo: Identifiable {
        let id = UUID()
        let message: String
        let style: ToastView.ToastStyle
    }

    init() {
        do {
            let schema = Schema([
                Sentence.self,
                VocabItem.self,
                ReviewState.self,
                AudioAsset.self,
                GenerationJob.self,
                Companion.self,
                SpriteMemory.self,
                UserPreference.self,
                LearningEvent.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func initialize() async {
        do {
            let context = modelContainer.mainContext

            // Load or create preferences
            let prefDescriptor = FetchDescriptor<UserPreference>()
            if let existing = try context.fetch(prefDescriptor).first {
                preferences = existing
            } else {
                context.insert(preferences)
                try context.save()
            }

            // Load or create companion
            let compDescriptor = FetchDescriptor<Companion>(
                predicate: #Predicate<Companion> { $0.active == true }
            )

            if let existing = try context.fetch(compDescriptor).first {
                activeCompanion = existing
            } else {
                let companion = Companion(displayName: "小豆")
                context.insert(companion)

                // Create default sprite memories
                let memories = SpriteMemoryPresets.all(for: companion.id)
                for memory in memories {
                    context.insert(memory)
                }

                try context.save()
                activeCompanion = companion
            }

            // Wire up services.
            // M0: Mock services for prototype flow.
            // M1: Real services use SelahAPIClient (needs Supabase auth token).
            //     When not authenticated, we fall back to Mock for offline UX.
            //     The app should call apiClient.signIn() before using real services.
            // For now, keep Mock for speech and use Mock for sentence/audio.
            // When the user logs in, SelahApp can swap to real implementations.
            let mockSentence = MockSentenceGenerationService()
            let mockAudio = MockAudioGenerationService()
            let mockSpeech = MockSpeechRecognitionService()

            sentenceGenService = mockSentence
            audioGenService = mockAudio
            speechService = mockSpeech

            // M1: Real speech recognition is always available (iOS native).
            // Swap in the real speech recognizer so recording works on device.
            #if canImport(Speech)
            speechService = SpeechRecognitionServiceImpl()
            #endif

            // M3: Wire up SwiftData-backed repositories + engines.
            let sentenceRepo = SentenceRepositoryImpl(modelContext: context)
            let eventRepo = LearningEventRepositoryImpl(modelContext: context)
            let vocabRepo = VocabRepositoryImpl(modelContext: context)

            let scheduler = ReviewSchedulerImpl(
                sentenceRepo: sentenceRepo,
                learningEventRepo: eventRepo
            )
            let engine = RecommendationEngineImpl(
                sentenceRepo: sentenceRepo,
                reviewScheduler: scheduler
            )
            reviewScheduler = scheduler
            recommendationEngine = engine

            // Vocabulary help use case also wired with real repos.
            vocabularyHelp = VocabularyHelpUseCaseImpl(
                vocabRepo: vocabRepo,
                learningEventRepo: eventRepo
            )
        } catch {
            print("Initialization error: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Launch Screen

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.selahBgPrimary.ignoresSafeArea()
            VStack(spacing: SelahSpacing.md) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.selahAmber, Color.selahAmber.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Text("Selah")
                    .font(.selahDisplayLarge)
                    .foregroundColor(.selahTextPrimary)
            }
        }
    }
}
