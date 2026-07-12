import XCTest
@testable import Selah

final class ServiceImplementationTests: XCTestCase {

    // MARK: - Mock API Client for testing

    final class MockAPIClient: SelahAPIClientProtocol {

        var generateSentenceCallCount = 0
        var generateAudioCallCount = 0
        var fetchBootstrapCallCount = 0

        var generateSentenceResult: GeneratedSentenceResult?
        var generateAudioResult: GeneratedAudioResult?
        var fetchBootstrapResult: BootstrapConfig?
        var generateSentenceError: Error?
        var generateAudioError: Error?
        var fetchBootstrapError: Error?

        func generateSentence(
            sourceText: String,
            sourceLanguage: SourceLanguage,
            targetLanguage: TargetLanguage,
            categoryHint: SentenceCategory?
        ) async throws -> GeneratedSentenceResult {
            generateSentenceCallCount += 1
            if let error = generateSentenceError { throw error }
            return generateSentenceResult ?? GeneratedSentenceResult(
                targetText: "default",
                category: .dailyLife,
                vocabulary: [],
                deconstruction: [],
                promptVersion: "v8.0-test"
            )
        }

        func generateAudio(
            sentenceID: UUID,
            targetText: String,
            voiceProfile: VoiceProfile,
            reason: AudioGenerationReason
        ) async throws -> GeneratedAudioResult {
            generateAudioCallCount += 1
            if let error = generateAudioError { throw error }
            return generateAudioResult ?? GeneratedAudioResult(
                status: .ready,
                voiceProfile: .gentleNatural,
                downloadURL: nil,
                localFilePath: "/test/audio.mp3",
                durationMs: 3000
            )
        }

        func fetchBootstrap() async throws -> BootstrapConfig {
            fetchBootstrapCallCount += 1
            if let error = fetchBootstrapError { throw error }
            return fetchBootstrapResult ?? BootstrapConfig(
                sourceLanguages: ["zh-Hant"],
                targetLanguages: ["en"],
                defaultVoiceProfile: "gentle-natural",
                voiceProfiles: [],
                seedSentencePackVersion: "v2",
                promptVersion: "v8.0",
                featureFlags: [:]
            )
        }
    }

    // MARK: - Properties

    var mockClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockClient = MockAPIClient()
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    // MARK: - SentenceGenerationServiceImpl

    func testSentenceGenerationServiceImpl_delegatesToClient() async throws {
        let service = SentenceGenerationServiceImpl(apiClient: mockClient)

        mockClient.generateSentenceResult = GeneratedSentenceResult(
            targetText: "I'm so tired",
            category: .work,
            vocabulary: [],
            deconstruction: [],
            promptVersion: "v8.0-test"
        )

        let result = try await service.generateSentence(
            sourceText: "我好累",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: .work
        )

        XCTAssertEqual(mockClient.generateSentenceCallCount, 1)
        XCTAssertEqual(result.targetText, "I'm so tired")
    }

    func testSentenceGenerationServiceImpl_propagatesError() async {
        let service = SentenceGenerationServiceImpl(apiClient: mockClient)
        mockClient.generateSentenceError = SelahAPIError.notAuthenticated

        do {
            _ = try await service.generateSentence(
                sourceText: "test",
                sourceLanguage: .zhHant,
                targetLanguage: .en,
                categoryHint: nil
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(mockClient.generateSentenceCallCount, 1)
        }
    }

    // MARK: - AudioGenerationServiceImpl

    func testAudioGenerationServiceImpl_delegatesToClient() async throws {
        let service = AudioGenerationServiceImpl(apiClient: mockClient)
        let sentenceID = UUID()

        mockClient.generateAudioResult = GeneratedAudioResult(
            status: .ready,
            voiceProfile: .dailyBright,
            downloadURL: URL(string: "https://example.com/audio.mp3"),
            localFilePath: nil,
            durationMs: 4500
        )

        let result = try await service.generateAudio(
            sentenceID: sentenceID,
            targetText: "Hello",
            voiceProfile: .dailyBright,
            reason: .initialGeneration
        )

        XCTAssertEqual(mockClient.generateAudioCallCount, 1)
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.voiceProfile, .dailyBright)
        XCTAssertEqual(result.durationMs, 4500)
    }

    func testAudioGenerationServiceImpl_propagatesError() async {
        let service = AudioGenerationServiceImpl(apiClient: mockClient)
        mockClient.generateAudioError = SelahAPIError.serverError(503, "unavailable")

        do {
            _ = try await service.generateAudio(
                sentenceID: UUID(),
                targetText: "test",
                voiceProfile: .gentleNatural,
                reason: .initialGeneration
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(mockClient.generateAudioCallCount, 1)
        }
    }

    // MARK: - GeneratedAudioResult

    func testGeneratedAudioResult_isReady() {
        let ready = GeneratedAudioResult(
            status: .ready,
            voiceProfile: .gentleNatural,
            downloadURL: URL(string: "https://example.com/audio.mp3"),
            localFilePath: nil,
            durationMs: 1000
        )
        XCTAssertTrue(ready.isReady)

        let queued = GeneratedAudioResult(
            status: .queued,
            voiceProfile: .gentleNatural,
            downloadURL: nil,
            localFilePath: nil,
            durationMs: 0
        )
        XCTAssertFalse(queued.isReady)

        let failed = GeneratedAudioResult(
            status: .failed,
            voiceProfile: .gentleNatural,
            downloadURL: nil,
            localFilePath: nil,
            durationMs: 0
        )
        XCTAssertFalse(failed.isReady)
    }
}
