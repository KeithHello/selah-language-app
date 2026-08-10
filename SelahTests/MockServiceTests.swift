import XCTest
@testable import Selah

/// Tests for the MockSentenceGenerationService.
/// Verifies mock translation behavior with known and unknown inputs.
final class MockSentenceGenerationServiceTests: XCTestCase {

    func testGenerateKnownSentence() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "今天工作忙翻了，但還是準時下班了",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.targetText, "I was swamped at work today, but I still got off on time.")
        XCTAssertEqual(result.category, .work)
        XCTAssertEqual(result.promptVersion, "v8.0-mock")
        XCTAssertFalse(result.vocabulary.isEmpty)
        XCTAssertFalse(result.deconstruction.isEmpty)
    }

    func testGenerateAnotherKnownSentence() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "同事說的笑話一點都不好笑",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.targetText, "My coworker's joke wasn't funny at all.")
        XCTAssertEqual(result.category, .friends)
    }

    func testGenerateThirdKnownSentence() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "我真的受不了這個天氣了",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.targetText, "I seriously can't take this weather anymore.")
        XCTAssertEqual(result.category, .vent)
    }

    func testGenerateFourthKnownSentence() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "我今天想吃拉麵",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.targetText, "I'm in the mood for ramen today.")
        XCTAssertEqual(result.category, .dailyLife)
    }

    func testGenerateUnknownSentenceReturnsFallback() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "這是一句完全沒見過的句子",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: .heartfelt
        )

        // Fallback should return a generic translation
        XCTAssertFalse(result.targetText.isEmpty)
        XCTAssertEqual(result.category, .heartfelt) // uses hint
        XCTAssertEqual(result.promptVersion, "v8.0-mock")
    }

    func testGenerateWithPartialMatch() async throws {
        let service = MockSentenceGenerationService()

        // Partial match: sourceText contains part of known sentence
        let result = try await service.generateSentence(
            sourceText: "今天工作忙翻了",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        // Should match the first mock entry
        XCTAssertEqual(result.targetText, "I was swamped at work today, but I still got off on time.")
    }

    func testGenerateVocabularyContainsExpectedItems() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "今天工作忙翻了，但還是準時下班了",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.vocabulary.count, 2)
        XCTAssertEqual(result.vocabulary[0].surfaceText, "swamped")
        XCTAssertEqual(result.vocabulary[0].meaningInContext, "忙翻了")
        XCTAssertEqual(result.vocabulary[1].surfaceText, "got off on time")
        XCTAssertEqual(result.vocabulary[1].meaningInContext, "準時下班")
    }

    func testGenerateDeconstructionContainsExpectedItems() async throws {
        let service = MockSentenceGenerationService()

        let result = try await service.generateSentence(
            sourceText: "今天工作忙翻了，但還是準時下班了",
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            categoryHint: nil
        )

        XCTAssertEqual(result.deconstruction.count, 2)
        XCTAssertEqual(result.deconstruction[0].surfaceText, "swamped")
        XCTAssertEqual(result.deconstruction[1].surfaceText, "got off on time")
    }
}

/// Tests for the MockAudioGenerationService.
final class MockAudioGenerationServiceTests: XCTestCase {

    func testGenerateAudioReturnsReadyStatus() async throws {
        let service = MockAudioGenerationService()

        let result = try await service.generateAudio(
            sentenceID: UUID(),
            targetText: "Hello world.",
            voiceProfile: .gentleNatural,
            reason: .initialGeneration
        )

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.voiceProfile, .gentleNatural)
        XCTAssertNotNil(result.localFilePath)
        XCTAssertTrue(result.durationMs >= 2000)
        XCTAssertTrue(result.durationMs <= 5000)
    }

    func testGenerateAudioWithDifferentVoices() async throws {
        let service = MockAudioGenerationService()

        for voice in VoiceProfile.allCases {
            let result = try await service.generateAudio(
                sentenceID: UUID(),
                targetText: "Test",
                voiceProfile: voice,
                reason: .initialGeneration
            )

            XCTAssertEqual(result.voiceProfile, voice)
            XCTAssertEqual(result.status, .ready)
        }
    }

    func testGenerateAudioWithDifferentReasons() async throws {
        let service = MockAudioGenerationService()

        for reason in [AudioGenerationReason.initialGeneration,
                        .manualRegeneration,
                        .voiceChangedRegeneration] {
            let result = try await service.generateAudio(
                sentenceID: UUID(),
                targetText: "Test",
                voiceProfile: .gentleNatural,
                reason: reason
            )

            XCTAssertEqual(result.status, .ready)
        }
    }

    func testGenerateAudioLocalFilePathContainsSentenceID() async throws {
        let service = MockAudioGenerationService()
        let sentenceID = UUID()

        let result = try await service.generateAudio(
            sentenceID: sentenceID,
            targetText: "Test",
            voiceProfile: .gentleNatural,
            reason: .initialGeneration
        )

        XCTAssertTrue(result.localFilePath?.contains(sentenceID.uuidString) ?? false)
    }
}

/// Tests for the MockSpeechRecognitionService.
final class MockSpeechRecognitionServiceTests: XCTestCase {

    func testRequestAuthorizationSucceeds() async {
        let service = MockSpeechRecognitionService()
        let authorized = await service.requestAuthorization()
        XCTAssertTrue(authorized)
    }

    func testStartReturnsTranscript() async throws {
        let service = MockSpeechRecognitionService()

        let stream = service.start(language: .zhHant)
        var result: String?

        for try await transcript in stream {
            result = transcript
            break
        }

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isEmpty ?? true)
    }

    func testStartReturnsDifferentTranscriptsSequentially() async throws {
        let service = MockSpeechRecognitionService()

        // First call
        let stream1 = service.start(language: .zhHant)
        var result1: String?
        for try await transcript in stream1 {
            result1 = transcript
            break
        }

        // Second call
        let stream2 = service.start(language: .zhHant)
        var result2: String?
        for try await transcript in stream2 {
            result2 = transcript
            break
        }

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        // They should be different (sequential mock transcripts)
        XCTAssertNotEqual(result1, result2)
    }

    func testStopDoesNotCrash() async throws {
        let service = MockSpeechRecognitionService()
        service.stop()
        // Should not crash
    }

    func testMockTranscriptsAreNonEmpty() async throws {
        let service = MockSpeechRecognitionService()

        // Collect 4 transcripts (full cycle)
        for _ in 0..<4 {
            let stream = service.start(language: .zhHant)
            for try await transcript in stream {
                XCTAssertFalse(transcript.isEmpty)
                break
            }
        }
    }
}
