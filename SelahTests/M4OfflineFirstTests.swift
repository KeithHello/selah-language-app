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

final class M4OfflineFirstTests: XCTestCase {
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
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(state, "error")
        XCTAssertNotNil(pendingOperation)
    }

    func testPendingOperationUsesSafeTraditionalChineseMessage() {
        let sentence = PendingOperation.sentenceTranslation(sourceText: "今天好累")
        let audio = PendingOperation.audioGeneration(sentenceID: UUID())

        XCTAssertTrue(sentence.message.contains("留在本機"))
        XCTAssertTrue(audio.message.contains("連線恢復"))
        XCTAssertNotEqual(sentence.message, audio.message)
    }
}
