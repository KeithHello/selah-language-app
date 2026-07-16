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
    case preparingCapture
    case reviewingSegments
    case translating
    case reviewingResult(result: GeneratedSentenceResult)
    case translatingBatch
    case reviewingBatch(results: [SegmentTranslationResult])
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
        case .preparingCapture: return "preparingCapture"
        case .reviewingSegments: return "reviewingSegments"
        case .translating: return "translating"
        case .reviewingResult: return "reviewingResult"
        case .translatingBatch: return "translatingBatch"
        case .reviewingBatch: return "reviewingBatch"
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
    @Published private(set) var segmentSuggestions: [CaptureSegmentSuggestion] = []

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
    private var captureDraftModel: CaptureDraft?

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

    // MARK: - Long capture preparation

    func prepareCapture(rawTranscript: String) {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            flowState = .error(message: "請先確認語音轉寫內容")
            return
        }

        let localPreparation = LearningCapturePreprocessor().prepare(transcript: trimmed)
        segmentSuggestions = localPreparation.segments
        persistCaptureDraft(localPreparation, status: .readyForReview)

        Task { [weak self] in
            guard let self else { return }
            guard await self.connectivity.currentStatus() == .online else {
                self.flowState = .reviewingSegments
                return
            }
            self.flowState = .preparingCapture
            do {
                let preparation = try await self.sentenceService.prepareCapture(
                    rawTranscript: trimmed,
                    sourceLanguage: .zhHant,
                    targetLanguage: .en
                )
                self.segmentSuggestions = preparation.segments
                self.persistCaptureDraft(preparation, status: .readyForReview)
                self.flowState = .reviewingSegments
            } catch {
                self.flowState = .reviewingSegments
            }
        }
    }

    func updateSegmentText(id: UUID, text: String) {
        guard let index = segmentSuggestions.firstIndex(where: { $0.id == id }) else { return }
        segmentSuggestions[index].sourceText = text
        persistCurrentCaptureDraft()
    }

    func setSegmentSelected(id: UUID, selected: Bool) {
        guard let index = segmentSuggestions.firstIndex(where: { $0.id == id }) else { return }
        segmentSuggestions[index].selected = selected
        persistCurrentCaptureDraft()
    }

    func mergeSegmentWithNext(id: UUID) {
        guard let index = segmentSuggestions.firstIndex(where: { $0.id == id }),
              index + 1 < segmentSuggestions.count else { return }
        let next = segmentSuggestions[index + 1]
        segmentSuggestions[index].sourceText += next.sourceText
        segmentSuggestions[index].selected = segmentSuggestions[index].selected || next.selected
        segmentSuggestions.remove(at: index + 1)
        segmentSuggestions = segmentSuggestions.enumerated().map { offset, segment in
            CaptureSegmentSuggestion(
                id: segment.id,
                orderIndex: offset,
                originalText: segment.originalText,
                sourceText: segment.sourceText,
                removedText: segment.removedText,
                selected: segment.selected
            )
        }
        persistCurrentCaptureDraft()
    }

    func translateSelectedSegments() {
        let selected = segmentSuggestions.filter {
            $0.selected && !$0.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !selected.isEmpty else {
            flowState = .error(message: "至少選擇一句要學習的內容")
            return
        }
        guard selected.count <= LearningCapturePreprocessor.defaultMaxSelectedSegments else {
            flowState = .error(message: "一次最多選擇五句，其他內容可以稍後再學")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard await self.connectivity.currentStatus() == .online else {
                self.persistCurrentCaptureDraft(status: .readyForReview)
                self.flowState = .error(message: "目前離線，分句草稿已保留在本機")
                return
            }
            self.persistCurrentCaptureDraft(status: .translating)
            self.flowState = .translatingBatch
            do {
                let results = try await self.sentenceService.generateSentenceBatch(
                    segments: selected,
                    sourceLanguage: .zhHant,
                    targetLanguage: .en,
                    categoryHint: self.selectedCategory
                )
                self.flowState = .reviewingBatch(results: results)
            } catch let error as SelahAPIError {
                self.persistCurrentCaptureDraft(status: .failed)
                self.flowState = .error(message: error.errorDescription ?? "批量翻譯失敗")
            } catch {
                self.persistCurrentCaptureDraft(status: .failed)
                self.flowState = .error(message: "批量翻譯暫時沒有完成，請稍後再試")
            }
        }
    }

    func saveBatch(results: [SegmentTranslationResult]) {
        guard !results.isEmpty else { return }
        flowState = .saving
        Task { [weak self] in
            guard let self else { return }
            do {
                for result in results {
                    guard let segment = self.segmentSuggestions.first(where: { $0.id == result.segmentID }) else { continue }
                    let sentence = self.makeSentence(
                        targetText: result.targetText,
                        category: result.category,
                        vocabulary: result.vocabulary,
                        deconstruction: result.deconstruction,
                        sourceText: segment.sourceText
                    )
                    self.modelContext.insert(sentence)
                    let reviewState = ReviewState(
                        sentenceID: sentence.id,
                        state: .new,
                        nextReviewAt: Date(),
                        intervalDays: 1
                    )
                    self.modelContext.insert(reviewState)
                    sentence.reviewState = reviewState
                    let audioAsset = AudioAsset(
                        sentenceID: sentence.id,
                        voiceProfile: self.selectedVoiceProfile,
                        generationReason: .initialGeneration
                    )
                    audioAsset.generationStatus = .queued
                    self.modelContext.insert(audioAsset)
                    sentence.audioAssets.append(audioAsset)
                    self.modelContext.insert(LearningEvent.sentenceCreated(sentence))
                    if let vocabularyHelp = self.vocabularyHelp {
                        _ = try await vocabularyHelp.createFromCandidates(
                            sentenceID: sentence.id,
                            candidates: result.vocabulary
                        )
                    }
                    self.triggerAudioGeneration(
                        sentenceID: sentence.id,
                        targetText: result.targetText,
                        audioAsset: audioAsset
                    )
                }
                try self.modelContext.save()
                try self.unlockSentenceMilestones()
                self.persistCurrentCaptureDraft(status: .completed)
                self.flowState = .done
            } catch {
                self.persistCurrentCaptureDraft(status: .failed)
                self.flowState = .error(message: "學習語料保存失敗，草稿仍保留在本機")
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

    private func makeSentence(
        targetText: String,
        category: SentenceCategory?,
        vocabulary: [VocabCandidate],
        deconstruction: [DeconstructionItem],
        sourceText: String
    ) -> Sentence {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let deconJSON = (try? String(data: encoder.encode(deconstruction), encoding: .utf8)) ?? "[]"
        let vocabJSON = (try? String(data: encoder.encode(vocabulary), encoding: .utf8)) ?? "[]"
        return Sentence(
            sourceText: sourceText,
            targetText: targetText,
            category: category ?? selectedCategory ?? .dailyLife,
            origin: .userRecording,
            deconstructionJSON: deconJSON,
            vocabCandidatesJSON: vocabJSON
        )
    }

    private func persistCaptureDraft(
        _ preparation: CapturePreparation,
        status: CaptureDraftStatus
    ) {
        let capture = captureDraftModel ?? CaptureDraft(
            rawTranscript: preparation.rawTranscript,
            normalizedTranscript: preparation.normalizedTranscript
        )
        if captureDraftModel == nil {
            captureDraftModel = capture
            modelContext.insert(capture)
        }
        capture.rawTranscript = preparation.rawTranscript
        capture.normalizedTranscript = preparation.normalizedTranscript
        capture.status = status
        for segment in capture.segments {
            modelContext.delete(segment)
        }
        capture.segments = preparation.segments.map { suggestion in
            LearningSegmentDraft(
                id: suggestion.id,
                captureID: capture.id,
                orderIndex: suggestion.orderIndex,
                originalText: suggestion.originalText,
                sourceText: suggestion.sourceText,
                removedText: suggestion.removedText,
                selected: suggestion.selected
            )
        }
        try? modelContext.save()
    }

    private func persistCurrentCaptureDraft(status: CaptureDraftStatus? = nil) {
        guard let capture = captureDraftModel else { return }
        if let status { capture.status = status }
        for segment in capture.segments {
            modelContext.delete(segment)
        }
        capture.segments = segmentSuggestions.map { suggestion in
            LearningSegmentDraft(
                id: suggestion.id,
                captureID: capture.id,
                orderIndex: suggestion.orderIndex,
                originalText: suggestion.originalText,
                sourceText: suggestion.sourceText,
                removedText: suggestion.removedText,
                selected: suggestion.selected
            )
        }
        try? modelContext.save()
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
