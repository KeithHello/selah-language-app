import SwiftUI
import SwiftData

#if !SWIFT_PACKAGE
@main
#endif
struct SelahApp: App {

    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await appState.retryPendingGenerationJobs() }
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var preferences = UserPreference.default()
    @Published var activeCompanion: Companion?
    @Published var showToast: ToastInfo?
    @Published private(set) var connectivityStatus: ConnectivityStatus = .unknown

    let modelContainer: ModelContainer
    let connectivity: ConnectivityMonitor

    // Services (injected, initialized during `initialize()`)
    var sentenceGenService: (any SentenceGenerationService)?
    var audioGenService: (any AudioGenerationService)?
    var speechService: (any SpeechRecognitionService)?
    var recommendationEngine: (any RecommendationEngine)?
    var reviewScheduler: (any ReviewScheduler)?
    var vocabularyHelp: VocabularyHelpUseCaseImpl?
    var generationRetryQueue: GenerationRetryQueueImpl?

    struct ToastInfo: Identifiable {
        let id = UUID()
        let message: String
        let style: ToastView.ToastStyle
    }

    init() {
        connectivity = ConnectivityMonitor()
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

            let jobRepo = GenerationJobRepositoryImpl(modelContext: context)
            generationRetryQueue = GenerationRetryQueueImpl(
                jobRepo: jobRepo,
                audioService: audioGenService ?? mockAudio
            )
            connectivityStatus = await connectivity.refresh()
            try await generationRetryQueue?.recoverInterruptedJobs()
            if connectivityStatus.isOnline {
                try await generationRetryQueue?.retryDueJobs(now: Date())
            }
        } catch {
            // Keep diagnostics local and generic; never expose model or provider details in UI logs.
            showToast = ToastInfo(
                message: "目前還沒準備好，請稍後再試。",
                style: .info
            )
        }

        isLoading = false
    }

    func retryPendingGenerationJobs() async {
        guard let generationRetryQueue else { return }
        do {
            connectivityStatus = await connectivity.refresh()
            try await generationRetryQueue.recoverInterruptedJobs()
            guard connectivityStatus.isOnline else { return }
            try await generationRetryQueue.retryDueJobs(now: Date())
        } catch {
            showToast = ToastInfo(
                message: "背景處理暫時沒有完成，稍後會自動再試。",
                style: .info
            )
        }
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
