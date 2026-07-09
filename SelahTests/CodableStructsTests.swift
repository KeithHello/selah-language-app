import XCTest
@testable import Selah

/// Tests for the GeneratedSentenceResult and related Codable structs.
/// Verifies encoding/decoding round-trips and structural integrity.
final class CodableStructsTests: XCTestCase {

    // MARK: - GeneratedSentenceResult

    func testGeneratedSentenceResultEncoding() throws {
        let result = GeneratedSentenceResult(
            targetText: "I was swamped.",
            category: .work,
            vocabulary: [
                VocabCandidate(surfaceText: "swamped", meaningInContext: "忙翻了", suggestedHelpState: .learning)
            ],
            deconstruction: [
                DeconstructionItem(surfaceText: "swamped", meaning: "忙翻了", type: .phrase)
            ],
            promptVersion: "v8.0"
        )

        let data = try JSONEncoder().encode(result)
        XCTAssertGreaterThan(data.count, 0)

        let decoded = try JSONDecoder().decode(GeneratedSentenceResult.self, from: data)
        XCTAssertEqual(decoded.targetText, "I was swamped.")
        XCTAssertEqual(decoded.category, .work)
        XCTAssertEqual(decoded.promptVersion, "v8.0")
        XCTAssertEqual(decoded.vocabulary.count, 1)
        XCTAssertEqual(decoded.deconstruction.count, 1)
    }

    func testGeneratedSentenceResultWithNilCategory() throws {
        let result = GeneratedSentenceResult(
            targetText: "Test",
            category: nil,
            vocabulary: [],
            deconstruction: [],
            promptVersion: "v8.0"
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(GeneratedSentenceResult.self, from: data)
        XCTAssertNil(decoded.category)
        XCTAssertTrue(decoded.vocabulary.isEmpty)
        XCTAssertTrue(decoded.deconstruction.isEmpty)
    }

    // MARK: - VocabCandidate

    func testVocabCandidateEncoding() throws {
        let candidate = VocabCandidate(
            surfaceText: "swamped",
            meaningInContext: "忙翻了",
            suggestedHelpState: .learning
        )

        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(VocabCandidate.self, from: data)

        XCTAssertEqual(decoded.surfaceText, "swamped")
        XCTAssertEqual(decoded.meaningInContext, "忙翻了")
        XCTAssertEqual(decoded.suggestedHelpState, .learning)
    }

    func testVocabCandidateAllHelpStates() throws {
        for state in [VocabHelpState.new, .learning, .familiar, .owned] {
            let candidate = VocabCandidate(
                surfaceText: "test",
                meaningInContext: "測試",
                suggestedHelpState: state
            )
            let data = try JSONEncoder().encode(candidate)
            let decoded = try JSONDecoder().decode(VocabCandidate.self, from: data)
            XCTAssertEqual(decoded.suggestedHelpState, state)
        }
    }

    // MARK: - DeconstructionItem

    func testDeconstructionItemEncoding() throws {
        let item = DeconstructionItem(
            surfaceText: "swamped",
            meaning: "忙翻了、忙到不行",
            type: .phrase
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DeconstructionItem.self, from: data)

        XCTAssertEqual(decoded.surfaceText, "swamped")
        XCTAssertEqual(decoded.meaning, "忙翻了、忙到不行")
        XCTAssertEqual(decoded.type, .phrase)
    }

    func testDeconstructionItemPatternType() throws {
        let item = DeconstructionItem(
            surfaceText: "wasn't ... at all",
            meaning: "一點都不……",
            type: .pattern
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DeconstructionItem.self, from: data)
        XCTAssertEqual(decoded.type, .pattern)
    }

    // MARK: - GeneratedAudioResult

    func testGeneratedAudioResultProperties() {
        let result = GeneratedAudioResult(
            status: .ready,
            voiceProfile: .gentleNatural,
            downloadURL: URL(string: "https://example.com/audio.mp3"),
            localFilePath: "audio/test.mp3",
            durationMs: 3500
        )

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(result.voiceProfile, .gentleNatural)
        XCTAssertEqual(result.durationMs, 3500)
    }

    func testGeneratedAudioResultNotReady() {
        let result = GeneratedAudioResult(
            status: .failed,
            voiceProfile: .gentleNatural,
            downloadURL: nil,
            localFilePath: nil,
            durationMs: 0
        )

        XCTAssertFalse(result.isReady)
    }

    // MARK: - BootstrapConfig

    func testBootstrapConfigEncoding() throws {
        let config = BootstrapConfig(
            sourceLanguages: ["zh-Hant"],
            targetLanguages: ["en"],
            defaultVoiceProfile: "gentle-natural",
            voiceProfiles: [
                VoiceProfileConfig(id: "gentle-natural", label: "溫柔自然", description: "速度適中"),
                VoiceProfileConfig(id: "clear-slow", label: "清晰慢速", description: "更慢一點"),
                VoiceProfileConfig(id: "daily-bright", label: "日常輕快", description: "像朋友說話")
            ],
            seedSentencePackVersion: "v1.0",
            promptVersion: "v8.0",
            featureFlags: ["enable_japanese": false]
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BootstrapConfig.self, from: data)

        XCTAssertEqual(decoded.sourceLanguages, ["zh-Hant"])
        XCTAssertEqual(decoded.targetLanguages, ["en"])
        XCTAssertEqual(decoded.defaultVoiceProfile, "gentle-natural")
        XCTAssertEqual(decoded.voiceProfiles.count, 3)
        XCTAssertEqual(decoded.voiceProfiles[0].id, "gentle-natural")
        XCTAssertEqual(decoded.featureFlags["enable_japanese"], false)
    }

    // MARK: - TodayRecommendation

    func testTodayRecommendationStructure() {
        let recommendation = TodayRecommendation(
            type: .practice,
            reason: "有 3 句可以練習",
            sentenceCount: 3,
            reasonItems: [
                TodayRecommendation.ReasonItem(
                    id: UUID(),
                    sentencePreview: "今天工作忙翻了",
                    nextState: "現在",
                    plainReason: "之前聽過，現在剛好叫回來"
                )
            ]
        )

        XCTAssertEqual(recommendation.type, .practice)
        XCTAssertEqual(recommendation.sentenceCount, 3)
        XCTAssertEqual(recommendation.reasonItems.count, 1)
        XCTAssertEqual(recommendation.reasonItems[0].sentencePreview, "今天工作忙翻了")
    }

    // MARK: - ContextualBridge

    func testContextualBridgeVariants() {
        let bridges: [ContextualBridge.BridgeSuggestion] = [
            .practice(3),
            .listenMore(3),
            .previewMore(5),
            .recordAnother,
            .stop,
        ]

        XCTAssertEqual(bridges.count, 5)
    }

    // MARK: - GenerationError

    func testGenerationErrorProperties() {
        let error = GenerationError(
            code: "timeout",
            message: "Request timed out",
            isRetryable: true
        )

        XCTAssertEqual(error.code, "timeout")
        XCTAssertEqual(error.message, "Request timed out")
        XCTAssertTrue(error.isRetryable)
    }

    func testGenerationErrorNilCode() {
        let error = GenerationError(
            code: nil,
            message: "Unknown error",
            isRetryable: false
        )

        XCTAssertNil(error.code)
        XCTAssertFalse(error.isRetryable)
    }
}
