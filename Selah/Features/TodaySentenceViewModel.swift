import Foundation
import SwiftUI
import SwiftData

/// State machine for the Today Sentence creation flow.
///
/// Flow: idle -> recording -> recognizingText -> confirmingChinese
///       -> translating -> reviewingResult -> saving -> done
///       (any state can fall back to error with a retry path)
enum TodaySentenceFlowState {
    case idle
    case recording
    case recognizingText
    case confirmingChinese(transcript: String)
    case translating
    case reviewingResult(result: GeneratedSentenceResult)
    case saving
    case done
    case error(message: String)

    /// A simple string label for comparison and debugging.
    var label: String {
        switch self {
        case .idle: return "idle"
        case .recording: return "recording"
        case .recognizingText: return "recognizingText"
        case .confirmingChinese: return "confirmingChinese"
        case .translating: return "translating"
        case .reviewingResult: return "reviewingResult"
        case .saving: return "saving"
        case .done: return "done"
        case .error: return "error"
        }
    }
}

/// ViewModel for TodaySentenceView.
/// Manages the complete flow: voice recognition -> Chinese confirmation -> AI translation -> save.
@MainActor
final class TodaySentenceViewModel: ObservableObject {

    @Published var flowState: TodaySentenceFlowState = .idle
    @Published var selectedCategory: SentenceCategory? = nil
    @Published var selectedVoiceProfile: VoiceProfile = .gentleNatural
    @Published private(set) var sourceText = ""

    private let speechService: SpeechRecognitionService
    private let sentenceService: SentenceGenerationService
    private let audioService: AudioGenerationService
    private let audioDeliveryCoordinator: AudioDeliveryCoordinator?
    private let modelContext: ModelContext
    private let connectivity: any ConnectivityProviding
    private let generationRetryQueue: (any GenerationRetryQueue)?
    private let vocabularyHelp: VocabularyHelpUseCaseImpl?
    private let memoryUnlockService: SpriteMemoryUnlockService?
    private let companionID: UUID?

    @Published private(set) var pendingOperation: PendingOperation?

    // Track recognition stream for cancellation
    private var recognitionTask: Task<Void, Never>?

    init(
        speechService: SpeechRecognitionService,
        sentenceService: SentenceGenerationService,
        audioService: AudioGenerationService,
        audioDeliveryCoordinator: AudioDeliveryCoordinator? = nil,
        modelContext: ModelContext,
        connectivity: any ConnectivityProviding = ConnectivityMonitor(initialStatus: .online),
        generationRetryQueue: (any GenerationRetryQueue)? = nil,
        vocabularyHelp: VocabularyHelpUseCaseImpl? = nil,
        memoryUnlockService: SpriteMemoryUnlockService? = nil,
        companionID: UUID? = nil,
        defaultVoiceProfile: VoiceProfile = .gentleNatural
    ) {
        self.speechService = speechService
        self.sentenceService = sentenceService
        self.audioService = audioService
        self.audioDeliveryCoordinator = audioDeliveryCoordinator
        self.modelContext = modelContext
        self.connectivity = connectivity
        self.generationRetryQueue = generationRetryQueue
        self.vocabularyHelp = vocabularyHelp
        self.memoryUnlockService = memoryUnlockService
        self.companionID = companionID
        self.selectedVoiceProfile = defaultVoiceProfile
    }

    // MARK: - Recording

    func startRecording() {
        flowState = .recording

        recognitionTask = Task { [weak self] in
            guard let self else { return }

            guard await self.speechService.requestAuthorization() else {
                self.flowState = .error(message: "需要麥克風與語音辨識權限才能使用語音輸入。")
                return
            }

            do {
                let stream = self.speechService.start(language: .zhHant)
                self.flowState = .recognizingText

                var transcript = ""
                for try await partial in stream {
                    transcript = partial
                    self.flowState = .confirmingChinese(transcript: transcript)
                }

                // If we got a non-empty transcript, stay in confirming state
                if transcript.isEmpty {
                    self.flowState = .error(message: "沒有聽到聲音，再試一次？")
                }
                // If transcript is non-empty, flowState is already .confirmingChinese
            } catch {
                self.flowState = .error(message: "語音識別暫時沒有完成，請再試一次。")
            }
        }
    }

    func stopRecording() {
        speechService.stop()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    /// Cancel and return to idle.
    func cancel() {
        stopRecording()
        sourceText = ""
        flowState = .idle
    }

    /// Clear error and return to idle.
    func dismissError() {
        flowState = .idle
    }

    // MARK: - Translation

    func translate(chineseText: String) {
        let normalizedText = chineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            flowState = .error(message: "請輸入中文句子")
            return
        }
        sourceText = normalizedText

        Task { [weak self] in
            guard let self else { return }
            if await self.connectivity.currentStatus() != .online {
                self.pendingOperation = .sentenceTranslation(sourceText: normalizedText)
                self.flowState = .error(message: self.pendingOperation?.message ?? "目前離線，這句話先留在本機。")
                return
            }

            self.flowState = .translating

            do {
                let result = try await self.sentenceService.generateSentence(
                    sourceText: normalizedText,
                    sourceLanguage: .zhHant,
                    targetLanguage: .en,
                    categoryHint: self.selectedCategory
                )
                self.flowState = .reviewingResult(result: result)
            } catch let error as SelahAPIError {
                self.flowState = .error(message: error.errorDescription ?? "翻譯失敗")
            } catch {
                self.flowState = .error(message: "翻譯暫時沒有完成，請稍後再試。")
            }
        }
    }

    // MARK: - Save

    func save(result: GeneratedSentenceResult, sourceText: String) {
        flowState = .saving

        Task { [weak self] in
            guard let self else { return }

            // Create Sentence
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase

            let deconJSON = (try? String(data: encoder.encode(result.deconstruction), encoding: .utf8)) ?? "[]"
            let vocabJSON = (try? String(data: encoder.encode(result.vocabulary), encoding: .utf8)) ?? "[]"

            let sentence = Sentence(
                sourceText: sourceText,
                targetText: result.targetText,
                category: result.category ?? self.selectedCategory ?? .dailyLife,
                origin: .userRecording,
                deconstructionJSON: deconJSON,
                vocabCandidatesJSON: vocabJSON
            )
            self.modelContext.insert(sentence)

            // Create ReviewState (new, due today)
            let reviewState = ReviewState(
                sentenceID: sentence.id,
                state: .new,
                nextReviewAt: Date(),
                intervalDays: 1
            )
            reviewState.sentenceID = sentence.id
            self.modelContext.insert(reviewState)
            sentence.reviewState = reviewState

            // Create AudioAsset (queued, will be generated async)
            let audioAsset = AudioAsset(
                sentenceID: sentence.id,
                voiceProfile: self.selectedVoiceProfile,
                generationReason: .initialGeneration
            )
            audioAsset.generationStatus = .queued
            self.modelContext.insert(audioAsset)
            sentence.audioAssets.append(audioAsset)

            self.modelContext.insert(LearningEvent.sentenceCreated(sentence))

            // Save to SwiftData
            do {
                try self.modelContext.save()
                if let vocabularyHelp = self.vocabularyHelp {
                    _ = try await vocabularyHelp.createFromCandidates(
                        sentenceID: sentence.id,
                        candidates: result.vocabulary
                    )
                }
                try self.unlockSentenceMilestones()
            } catch {
                self.flowState = .error(message: "儲存暫時沒有完成，請稍後再試。")
                return
            }

            // Trigger async audio generation (non-blocking). Offline devices
            // keep the sentence and queued asset; the foreground retry queue
            // will process it after connectivity returns.
            self.triggerAudioGeneration(
                sentenceID: sentence.id,
                targetText: result.targetText,
                audioAsset: audioAsset
            )

            self.flowState = .done
        }
    }

    // MARK: - Private

    private func unlockSentenceMilestones() throws {
        guard let memoryUnlockService, let companionID else { return }
        let userOrigin = SentenceOrigin.userRecording.rawValue
        let userSentences = try modelContext.fetch(
            FetchDescriptor<Sentence>(
                predicate: #Predicate<Sentence> { $0.originRaw == userOrigin && !$0.archived }
            )
        )
        try memoryUnlockService.unlock(
            for: .sentenceCount(count: userSentences.count),
            companionID: companionID
        )
        if Set(userSentences.map(\.category)).count == SentenceCategory.allCases.count {
            try memoryUnlockService.unlock(for: .allCategoriesCovered, companionID: companionID)
        }
    }

    private func triggerAudioGeneration(
        sentenceID: UUID,
        targetText: String,
        audioAsset: AudioAsset
    ) {
        Task { [weak self] in
            guard let self else { return }
            if await self.connectivity.currentStatus() != .online {
                audioAsset.generationStatus = .queued
                self.pendingOperation = .audioGeneration(sentenceID: sentenceID)
                await self.enqueueAudioRetry(
                    sentenceID: sentenceID,
                    targetText: targetText
                )
                try? self.modelContext.save()
                return
            }

            audioAsset.generationStatus = .generating

            do {
                if let audioDeliveryCoordinator = self.audioDeliveryCoordinator {
                    _ = try await audioDeliveryCoordinator.generateAndCache(
                        asset: audioAsset,
                        sentenceID: sentenceID,
                        targetText: targetText
                    )
                    return
                }
                let result = try await self.audioService.generateAudio(
                    sentenceID: sentenceID,
                    targetText: targetText,
                    voiceProfile: self.selectedVoiceProfile,
                    reason: .initialGeneration
                )

                if result.isReady {
                    audioAsset.generationStatus = .ready
                    audioAsset.durationMs = result.durationMs
                    if let path = result.localFilePath {
                        audioAsset.localFilePath = path
                    }
                    if let url = result.downloadURL {
                        audioAsset.remoteAssetID = url.absoluteString
                    }
                    try? self.modelContext.save()
                } else {
                    audioAsset.generationStatus = .failed
                    try? self.modelContext.save()
                }
            } catch {
                audioAsset.generationStatus = .failed
                await self.enqueueAudioRetry(
                    sentenceID: sentenceID,
                    targetText: targetText
                )
                try? self.modelContext.save()
            }
        }
    }

    private func enqueueAudioRetry(sentenceID: UUID, targetText: String) async {
        guard let generationRetryQueue else { return }
        let payload = AudioGenerationRetryPayload(
            targetText: targetText,
            voiceProfile: selectedVoiceProfile,
            reason: .initialGeneration
        )
        guard let job = try? GenerationJob(
            sentenceID: sentenceID,
            jobType: .audioGeneration,
            audioPayload: payload
        ) else { return }
        try? await generationRetryQueue.enqueue(job)
    }
}
