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
            if appState.persistenceRecoveryRequired {
                PersistenceRecoveryView()
            } else if appState.isLoading {
                LaunchScreen()
                    .task {
                        await appState.initialize()
                    }
            } else if appState.authenticationState == .configurationMissing {
                MissingRuntimeConfigurationView()
                    .environmentObject(appState)
            } else if appState.authenticationState == .signedOut {
                AuthenticationView()
                    .environmentObject(appState)
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
            Task { await appState.handleScenePhase(phase) }
        }
    }
}

// MARK: - App State

enum AppAuthenticationState: Equatable {
    case configurationMissing
    case signedOut
    case signedIn
}

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var preferences = UserPreference.default()
    @Published var activeCompanion: Companion?
    @Published var showToast: ToastInfo?
    @Published private(set) var connectivityStatus: ConnectivityStatus = .unknown
    @Published private(set) var authenticationState: AppAuthenticationState = .configurationMissing
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authenticationError: String?
    @Published private(set) var persistenceRecoveryRequired = false

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
    private(set) var audioDeliveryCoordinator: AudioDeliveryCoordinator?
    private(set) var memoryUnlockService: SpriteMemoryUnlockService?
    private var preferenceStore: UserPreferenceStore?
    private var onboardingCompletionService: OnboardingCompletionService?
    private var apiClient: SelahAPIClient?
    private let widgetSnapshotStore = WidgetSnapshotStore()
    #if os(iOS)
    private let backgroundRefreshScheduler = BackgroundRefreshScheduler()
    #endif
    #if canImport(UserNotifications)
    private let notificationService = LocalNotificationService(client: UserNotificationsClient())
    #endif

    struct ToastInfo: Identifiable {
        let id = UUID()
        let message: String
        let style: ToastView.ToastStyle
    }

    init() {
        connectivity = ConnectivityMonitor()
        do {
            let schema = Schema(versionedSchema: SelahSchemaV2.self)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: SelahMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            persistenceRecoveryRequired = true
            do {
                let schema = Schema(versionedSchema: SelahSchemaV2.self)
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: SelahMigrationPlan.self,
                    configurations: [fallback]
                )
            } catch {
                fatalError("Failed to create the recovery ModelContainer: \(error)")
            }
        }

        #if os(iOS)
        backgroundRefreshScheduler.register { [weak self] in
            await self?.retryPendingGenerationJobs()
            await self?.refreshWidgetSnapshot()
        }
        #endif
    }

    func initialize() async {
        do {
            let context = modelContainer.mainContext
            preferenceStore = UserPreferenceStore(modelContext: context)
            onboardingCompletionService = OnboardingCompletionService(modelContext: context)
            memoryUnlockService = SpriteMemoryUnlockService(modelContext: context)

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
                try context.save()
                activeCompanion = companion
            }

            if let companionID = activeCompanion?.id {
                try memoryUnlockService?.ensurePresets(for: companionID)
                try memoryUnlockService?.unlock(for: .appOpen(count: 1), companionID: companionID)
            }

            // Native speech recognition is device-local. Sentence and audio
            // generation are configured only after a real authenticated session.
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

            connectivityStatus = await connectivity.refresh()
            try await configureNetworkServices(modelContext: context)
            await refreshWidgetSnapshot()
        } catch {
            // Keep diagnostics local and generic; never expose model or provider details in UI logs.
            showToast = ToastInfo(
                message: "目前還沒準備好，請稍後再試。",
                style: .info
            )
        }

        isLoading = false
    }

    private func configureNetworkServices(modelContext: ModelContext) async throws {
        guard let configuration = SelahRuntimeConfiguration.load() else {
            authenticationState = .configurationMissing
            return
        }

        let client = SelahAPIClient(
            supabaseURL: configuration.supabaseURL,
            publishableKey: configuration.publishableKey
        )
        apiClient = client
        if try client.restoreSession() {
            try await activateAuthenticatedServices(client: client, modelContext: modelContext)
        } else {
            authenticationState = .signedOut
        }
    }

    private func activateAuthenticatedServices(
        client: SelahAPIClient,
        modelContext: ModelContext
    ) async throws {
        let sentenceService = SentenceGenerationServiceImpl(apiClient: client)
        let audioService = AudioGenerationServiceImpl(apiClient: client)
        let cacheService = try AudioCacheService()
        let deliveryCoordinator = AudioDeliveryCoordinator(
            audioService: audioService,
            cacheService: cacheService,
            modelContext: modelContext
        )
        sentenceGenService = sentenceService
        audioGenService = audioService
        audioDeliveryCoordinator = deliveryCoordinator
        generationRetryQueue = GenerationRetryQueueImpl(
            jobRepo: GenerationJobRepositoryImpl(modelContext: modelContext),
            audioService: audioService,
            audioDeliveryCoordinator: deliveryCoordinator
        )
        authenticationState = .signedIn
        try await generationRetryQueue?.recoverInterruptedJobs()
        if connectivityStatus.isOnline {
            try await generationRetryQueue?.retryDueJobs(now: Date())
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate(email: email, password: password, createAccount: false)
    }

    func signUp(email: String, password: String) async {
        await authenticate(email: email, password: password, createAccount: true)
    }

    private func authenticate(email: String, password: String, createAccount: Bool) async {
        guard let apiClient else {
            authenticationState = .configurationMissing
            return
        }
        isAuthenticating = true
        authenticationError = nil
        defer { isAuthenticating = false }
        do {
            if createAccount {
                try await apiClient.signUp(email: email, password: password)
            }
            try await apiClient.signIn(email: email, password: password)
            connectivityStatus = await connectivity.refresh()
            try await activateAuthenticatedServices(
                client: apiClient,
                modelContext: modelContainer.mainContext
            )
        } catch {
            authenticationState = .signedOut
            authenticationError = createAccount
                ? "帳號建立或登入沒有完成，請檢查 Email 與密碼。"
                : "登入沒有完成，請檢查 Email 與密碼。"
        }
    }

    func signOut() {
        do {
            try apiClient?.clearSession()
            sentenceGenService = nil
            audioGenService = nil
            audioDeliveryCoordinator = nil
            generationRetryQueue = nil
            authenticationState = .signedOut
        } catch {
            showToast = ToastInfo(message: "登出暫時沒有完成，請稍後再試。", style: .info)
        }
    }

    func savePreferences(synchronizeNotifications: Bool = false) async {
        do {
            try preferenceStore?.save(preferences)
            #if canImport(UserNotifications)
            if synchronizeNotifications {
                try await notificationService.synchronize(
                    preference: LocalNotificationPreferences(
                        enabled: preferences.notificationEnabled,
                        time: preferences.notificationTime
                    )
                )
            }
            #endif
        } catch LocalNotificationError.permissionDenied {
            preferences.notificationEnabled = false
            try? preferenceStore?.save(preferences)
            showToast = ToastInfo(message: "通知權限未開啟，提醒已保持關閉。", style: .info)
        } catch {
            showToast = ToastInfo(message: "設定暫時無法儲存，請稍後再試。", style: .info)
        }
    }

    func completeOnboarding(name: String, selectedSeeds: [OnboardingSeedPreset]) {
        guard let activeCompanion, let onboardingCompletionService else { return }
        do {
            try onboardingCompletionService.complete(
                companionName: name,
                selectedSeeds: selectedSeeds,
                companion: activeCompanion,
                preference: preferences
            )
        } catch {
            showToast = ToastInfo(message: "初始內容暫時無法儲存，請稍後再試。", style: .info)
        }
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

    func handleScenePhase(_ phase: ScenePhase) async {
        switch phase {
        case .active:
            await retryPendingGenerationJobs()
            await refreshWidgetSnapshot()
        case .background:
            await refreshWidgetSnapshot()
            #if os(iOS)
            try? backgroundRefreshScheduler.schedule()
            #endif
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func refreshWidgetSnapshot(now: Date = Date()) async {
        do {
            let context = modelContainer.mainContext
            let sentences = try context.fetch(FetchDescriptor<Sentence>())
                .filter { !$0.archived }
            let todayCount = sentences.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: now) }.count
            let listenedCount = sentences.filter { $0.listenCompletedAt != nil }.count
            let dueCount = sentences.filter { sentence in
                guard let review = sentence.reviewState else { return false }
                return review.nextReviewAt <= now && (review.state == .learning || review.state == .familiar)
            }.count
            let recommendation = try await recommendationEngine?.recommendNextAction(now: now)
            let snapshot = WidgetReadySnapshotBuilder().build(
                counts: WidgetReadyCounts(
                    todaySentenceCount: todayCount,
                    listenedCount: listenedCount,
                    dueReviewCount: dueCount
                ),
                recommendation: recommendation?.type.displayName ?? "今天留一句給自己",
                companionDisplayName: activeCompanion?.displayName ?? "語言精靈",
                generatedAt: now
            )
            try widgetSnapshotStore.save(snapshot)
        } catch {
            // Widget data is best-effort and must never block the main learning flow.
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

struct PersistenceRecoveryView: View {
    var body: some View {
        ZStack {
            Color.selahBgPrimary.ignoresSafeArea()
            VStack(spacing: SelahSpacing.md) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 42))
                    .foregroundColor(.selahAmber)

                Text("學習資料需要處理")
                    .font(.selahDisplayLarge)
                    .foregroundColor(.selahTextPrimary)

                Text("Selah 無法安全升級本機資料，因此沒有刪除或重建任何內容。請保留 App，更新至較新版本後再重新開啟。")
                    .font(.selahBodyLarge)
                    .foregroundColor(.selahTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(SelahSpacing.xl)
        }
    }
}
