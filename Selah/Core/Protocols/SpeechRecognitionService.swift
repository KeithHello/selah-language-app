import Foundation

/// iOS native speech recognition service.
/// Uses SFSpeechRecognizer for on-device Chinese recognition.
protocol SpeechRecognitionService {
    /// Request permission before attempting to open the recognizer.
    func requestAuthorization() async -> Bool

    /// Start recognizing speech in the given language.
    /// Returns an async stream of partial/final transcripts.
    func start(language: SourceLanguage) -> AsyncThrowingStream<String, Error>

    /// Stop recognition and return the final transcript.
    func stop()
}

// MARK: - Errors

enum SpeechRecognitionError: Error {
    case notAuthorized
    case notAvailable
    case recognitionFailed(Error)
}
