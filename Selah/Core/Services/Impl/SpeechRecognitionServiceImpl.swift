import Foundation
#if canImport(Speech)
import Speech
import AVFoundation
#endif

/// Real iOS speech recognition service using SFSpeechRecognizer.
/// Supports zh-Hant-TW (Traditional Chinese) recognition with tap-to-talk flow.
///
/// On platforms where Speech framework is unavailable (macOS SPM build),
/// falls back to returning an error. On iOS this uses the native recognizer.
final class SpeechRecognitionServiceImpl: SpeechRecognitionService, @unchecked Sendable {

    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    /// Track authorization status for testing and UI decisions.
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    #endif

    init(localeIdentifier: String = "zh-Hant-TW") {
        #if canImport(Speech)
        let locale = Locale(identifier: localeIdentifier)
        recognizer = SFSpeechRecognizer(locale: locale)
        // Fallback to system default if zh-Hant-TW is not available
        if recognizer == nil {
            recognizer = SFSpeechRecognizer()
        }
        recognizer?.defaultTaskHint = .dictation
        #endif
    }

    // MARK: - SpeechRecognitionService

    func start(language: SourceLanguage) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.startInternal(continuation: continuation, language: language)
        }
    }

    func stop() {
        #if canImport(Speech)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        continuation?.finish()
        continuation = nil
        #endif
    }

    // MARK: - Authorization

    /// Request speech recognition authorization if not yet determined.
    /// Returns the current/new authorization status.
    func requestAuthorization() async -> Bool {
        #if canImport(Speech)
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
            return SFSpeechRecognizer.authorizationStatus() == .authorized
        }

        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                self.authorizationStatus = status
                cont.resume(returning: status == .authorized)
            }
        }
        #else
        return false
        #endif
    }

    var isAvailable: Bool {
        #if canImport(Speech)
        return recognizer?.isAvailable ?? false
        #else
        return false
        #endif
    }

    // MARK: - Private

    private func startInternal(
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        language: SourceLanguage
    ) {
        #if canImport(Speech)
        self.continuation = continuation

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            continuation.finish(throwing: SpeechRecognitionError.notAuthorized)
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            continuation.finish(throwing: SpeechRecognitionError.notAvailable)
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            continuation.finish(throwing: SpeechRecognitionError.recognitionFailed(error))
            return
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                continuation.finish(throwing: SpeechRecognitionError.recognitionFailed(error))
                return
            }

            if let result {
                let transcript = result.bestTranscription.formattedString
                continuation.yield(transcript)

                if result.isFinal {
                    continuation.finish()
                }
            }
        }

        // Configure audio engine input tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            continuation.finish(throwing: SpeechRecognitionError.recognitionFailed(error))
        }
        #else
        // On non-iOS platforms (e.g. macOS SPM), return error immediately
        continuation.finish(throwing: SpeechRecognitionError.notAvailable)
        #endif
    }
}
