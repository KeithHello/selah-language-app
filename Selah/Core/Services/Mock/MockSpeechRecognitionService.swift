import Foundation

/// Mock speech recognition service for prototyping.
/// Returns a simulated Chinese transcript after a delay.
actor MockSpeechRecognitionService: SpeechRecognitionService {

    private let mockDelay: UInt64 = 1_000_000_000  // 1 second
    private var mockTranscripts: [String] = [
        "今天工作忙翻了，但還是準時下班了",
        "同事說的笑話一點都不好笑",
        "我真的受不了這個天氣了",
        "我今天想吃拉麵",
    ]
    private var currentIndex = 0
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func start(language: SourceLanguage) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            let transcript = mockTranscripts[currentIndex % mockTranscripts.count]
            currentIndex += 1

            Task {
                try? await Task.sleep(nanoseconds: mockDelay)
                continuation.yield(transcript)
                continuation.finish()
            }
        }
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }
}
