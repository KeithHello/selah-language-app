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

    private let speechService: SpeechRecognitionService
    private let sentenceService: SentenceGenerationService
    private let audioService: AudioGenerationService
    private let modelContext: ModelContext

    // Track recognition stream for cancellation
    private var recognitionTask: Task<Void, Never>?

    init(
        speechService: SpeechRecognitionService,
        sentenceService: SentenceGenerationService,
        audioService: AudioGenerationService,
        modelContext: ModelContext,
        defaultVoiceProfile: VoiceProfile = .gentleNatural
    ) {
        self.speechService = speechService
        self.sentenceService = sentenceService
        self.audioService = audioService
        self.modelContext = modelContext
        self.selectedVoiceProfile = defaultVoiceProfile
    }

    // MARK: - Recording

    func startRecording() {
        flowState = .recording

        recognitionTask = Task { [weak self] in
            guard let self else { return }

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
                self.flowState = .error(message: "語音識別失敗：\(error.localizedDescription)")
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
        flowState = .idle
    }

    /// Clear error and return to idle.
    func dismissError() {
        flowState = .idle
    }

    // MARK: - Translation

    func translate(chineseText: String) {
        guard !chineseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            flowState = .error(message: "請輸入中文句子")
            return
        }

        flowState = .translating

        Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await self.sentenceService.generateSentence(
                    sourceText: chineseText,
                    sourceLanguage: .zhHant,
                    targetLanguage: .en,
                    categoryHint: self.selectedCategory
                )
                self.flowState = .reviewingResult(result: result)
            } catch let error as SelahAPIError {
                self.flowState = .error(message: error.errorDescription ?? "翻譯失敗")
            } catch {
                self.flowState = .error(message: "翻譯失敗：\(error.localizedDescription)")
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

            // Save to SwiftData
            do {
                try self.modelContext.save()
            } catch {
                self.flowState = .error(message: "儲存失敗：\(error.localizedDescription)")
                return
            }

            // Trigger async audio generation (non-blocking)
            self.triggerAudioGeneration(
                sentenceID: sentence.id,
                targetText: result.targetText,
                audioAsset: audioAsset
            )

            self.flowState = .done
        }
    }

    // MARK: - Private

    private func triggerAudioGeneration(
        sentenceID: UUID,
        targetText: String,
        audioAsset: AudioAsset
    ) {
        audioAsset.generationStatus = .generating

        Task { [weak self] in
            guard let self else { return }

            do {
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
                try? self.modelContext.save()
            }
        }
    }
}
