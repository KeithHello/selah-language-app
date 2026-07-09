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

    // Services (injected)
    var sentenceGenService: SentenceGenerationService!
    var audioGenService: AudioGenerationService!
    var speechService: SpeechRecognitionService!
    var recommendationEngine: RecommendationEngine!
    var reviewScheduler: ReviewScheduler!

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
                predicate: #Predicate { $0.active == true }
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

            // Wire up services with mock implementations
            let mockSentence = MockSentenceGenerationService()
            let mockAudio = MockAudioGenerationService()
            let mockSpeech = MockSpeechRecognitionService()

            sentenceGenService = mockSentence
            audioGenService = mockAudio
            speechService = mockSpeech

            // Wire up core engines with mock repositories
            // In production, these would use real SwiftData-backed repositories
            // For now, we'll use a simple in-memory approach
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
