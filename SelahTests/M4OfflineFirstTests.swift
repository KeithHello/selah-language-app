import XCTest
import SwiftData
@testable import Selah

private actor CountingSentenceService: SentenceGenerationService {
    private(set) var calls = 0

    func generateSentence(sourceText: String, sourceLanguage: SourceLanguage, targetLanguage: TargetLanguage, categoryHint: SentenceCategory?) async throws -> GeneratedSentenceResult {
        calls += 1
        return GeneratedSentenceResult(targetText: "Hello", category: .dailyLife, vocabulary: [], deconstruction: [], promptVersion: "test")
    }
}

private final class DeniedSpeechService: SpeechRecognitionService, @unchecked Sendable {
    private(set) var startCallCount = 0

    func requestAuthorization() async -> Bool { false }

    func start(language: SourceLanguage) -> AsyncThrowingStream<String, Error> {
        startCallCount += 1
        return AsyncThrowingStream { $0.finish() }
    }

    func stop() {}
}

final class M4OfflineFirstTests: XCTestCase {
    func testRecordingDoesNotStartWhenSpeechPermissionIsDenied() async {
        let speechService = DeniedSpeechService()
        let container = try! ModelContainer(
            for: Sentence.self,
            ReviewState.self,
            AudioAsset.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = await MainActor.run {
            TodaySentenceViewModel(
                speechService: speechService,
                sentenceService: MockSentenceGenerationService(),
                audioService: MockAudioGenerationService(),
                modelContext: container.mainContext
            )
        }

        await MainActor.run { vm.startRecording() }
        try? await Task.sleep(nanoseconds: 20_000_000)

        let state = await MainActor.run { vm.flowState.label }
        XCTAssertEqual(state, "error")
        XCTAssertEqual(speechService.startCallCount, 0)
    }

    func testConnectivityMonitorPublishesInjectedOfflineAndOnlineStates() async {
        let monitor = ConnectivityMonitor(initialStatus: .unknown) { .offline }

        let initialStatus = await monitor.currentStatus()
        XCTAssertEqual(initialStatus, .unknown)

        let refreshedStatus = await monitor.refresh()
        XCTAssertEqual(refreshedStatus, .offline)

        await monitor.setStatus(.online)
        let finalStatus = await monitor.currentStatus()
        XCTAssertTrue(finalStatus.isOnline)
    }

    func testOfflineTranslationDoesNotCallRemoteService() async {
        let service = CountingSentenceService()
        let monitor = ConnectivityMonitor(initialStatus: .offline)
        let container = try! ModelContainer(for: Sentence.self, ReviewState.self, AudioAsset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = await MainActor.run {
            TodaySentenceViewModel(
                speechService: MockSpeechRecognitionService(),
                sentenceService: service,
                audioService: MockAudioGenerationService(),
                modelContext: container.mainContext,
                connectivity: monitor
            )
        }

        await MainActor.run {
            vm.translate(chineseText: "今天好累")
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let calls = await service.calls
        let state = await MainActor.run { vm.flowState.label }
        let pendingOperation = await MainActor.run { vm.pendingOperation }
        let sourceText = await MainActor.run { vm.sourceText }
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(state, "error")
        XCTAssertNotNil(pendingOperation)
        XCTAssertEqual(sourceText, "今天好累")
    }

    func testPendingOperationUsesSafeTraditionalChineseMessage() {
        let sentence = PendingOperation.sentenceTranslation(sourceText: "今天好累")
        let audio = PendingOperation.audioGeneration(sentenceID: UUID())

        XCTAssertTrue(sentence.message.contains("留在本機"))
        XCTAssertTrue(audio.message.contains("連線恢復"))
        XCTAssertNotEqual(sentence.message, audio.message)
    }
}
