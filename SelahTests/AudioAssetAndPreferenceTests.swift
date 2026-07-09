import XCTest
@testable import Selah

/// Tests for the AudioAsset model.
/// Covers: initialization, convenience accessors, and status checks.
final class AudioAssetTests: XCTestCase {

    func testAudioAssetInitialization() {
        let sentenceID = UUID()
        let asset = AudioAsset(
            sentenceID: sentenceID,
            voiceProfile: .gentleNatural,
            generationReason: .initialGeneration
        )

        XCTAssertEqual(asset.sentenceID, sentenceID)
        XCTAssertEqual(asset.voiceProfile, .gentleNatural)
        XCTAssertEqual(asset.generationStatus, .queued)
        XCTAssertEqual(asset.generationReason, .initialGeneration)
        XCTAssertEqual(asset.fileSizeBytes, 0)
        XCTAssertEqual(asset.durationMs, 0)
        XCTAssertNil(asset.localFilePath)
        XCTAssertNil(asset.remoteAssetID)
        XCTAssertNil(asset.downloadedAt)
        XCTAssertFalse(asset.isReady)
    }

    func testAudioAssetDefaultVoiceProfile() {
        let asset = AudioAsset(sentenceID: UUID())
        XCTAssertEqual(asset.voiceProfile, .gentleNatural)
    }

    func testAudioAssetStatusTransition() {
        let asset = AudioAsset(sentenceID: UUID())

        XCTAssertEqual(asset.generationStatus, .queued)
        XCTAssertFalse(asset.isReady)

        asset.generationStatus = .generating
        XCTAssertEqual(asset.generationStatus, .generating)
        XCTAssertFalse(asset.isReady)

        asset.generationStatus = .ready
        XCTAssertTrue(asset.isReady)

        asset.generationStatus = .failed
        XCTAssertFalse(asset.isReady)
    }

    func testAudioAssetAllVoiceProfiles() {
        for voice in VoiceProfile.allCases {
            let asset = AudioAsset(sentenceID: UUID(), voiceProfile: voice)
            XCTAssertEqual(asset.voiceProfile, voice)
        }
    }

    func testAudioAssetGenerationReasons() {
        let asset1 = AudioAsset(sentenceID: UUID(), generationReason: .initialGeneration)
        XCTAssertEqual(asset1.generationReason, .initialGeneration)

        let asset2 = AudioAsset(sentenceID: UUID(), generationReason: .manualRegeneration)
        XCTAssertEqual(asset2.generationReason, .manualRegeneration)

        let asset3 = AudioAsset(sentenceID: UUID(), generationReason: .voiceChangedRegeneration)
        XCTAssertEqual(asset3.generationReason, .voiceChangedRegeneration)
    }
}

/// Tests for the UserPreference model.
final class UserPreferenceTests: XCTestCase {

    func testDefaultInitialization() {
        let pref = UserPreference.default()

        XCTAssertEqual(pref.sourceLanguage, .zhHant)
        XCTAssertEqual(pref.targetLanguage, .en)
        XCTAssertEqual(pref.voiceProfile, .gentleNatural)
        XCTAssertEqual(pref.playbackSpeed, .learning)
        XCTAssertTrue(pref.notificationEnabled)
        XCTAssertEqual(pref.notificationTime, "20:00")
        XCTAssertFalse(pref.onboardingCompleted)
        XCTAssertNil(pref.activeCompanionID)
    }

    func testCustomInitialization() {
        let pref = UserPreference(
            sourceLanguage: .zhHant,
            targetLanguage: .en,
            voiceProfile: .clearSlow,
            playbackSpeed: .slow,
            notificationEnabled: false,
            notificationTime: "09:00",
            onboardingCompleted: true
        )

        XCTAssertEqual(pref.voiceProfile, .clearSlow)
        XCTAssertEqual(pref.playbackSpeed, .slow)
        XCTAssertFalse(pref.notificationEnabled)
        XCTAssertEqual(pref.notificationTime, "09:00")
        XCTAssertTrue(pref.onboardingCompleted)
    }

    func testVoiceProfileSetter() {
        let pref = UserPreference.default()
        pref.voiceProfile = .dailyBright
        XCTAssertEqual(pref.voiceProfile, .dailyBright)
        XCTAssertEqual(pref.voiceProfileRaw, "daily-bright")
    }

    func testPlaybackSpeedSetter() {
        let pref = UserPreference.default()
        pref.playbackSpeed = .fast
        XCTAssertEqual(pref.playbackSpeed, .fast)
        XCTAssertEqual(pref.playbackSpeedRaw, 1.2)
    }

    func testTargetLanguageSetter() {
        let pref = UserPreference.default()
        pref.targetLanguage = .ja
        XCTAssertEqual(pref.targetLanguage, .ja)
    }

    func testOnboardingCompletion() {
        let pref = UserPreference.default()
        XCTAssertFalse(pref.onboardingCompleted)
        pref.onboardingCompleted = true
        XCTAssertTrue(pref.onboardingCompleted)
    }
}

/// Tests for the LearningEvent model.
final class LearningEventTests: XCTestCase {

    func testLearningEventInitialization() {
        let sentenceID = UUID()
        let event = LearningEvent(
            sentenceID: sentenceID,
            eventType: .listenCompleted
        )

        XCTAssertEqual(event.sentenceID, sentenceID)
        XCTAssertEqual(event.eventType, .listenCompleted)
        XCTAssertEqual(event.metadataJSON, "{}")
        XCTAssertNotNil(event.happenedAt)
    }

    func testLearningEventWithoutSentenceID() {
        let event = LearningEvent(eventType: .previewCompleted)

        XCTAssertNil(event.sentenceID)
        XCTAssertEqual(event.eventType, .previewCompleted)
    }

    func testSentenceCreatedFactory() {
        let sentence = Sentence(
            sourceText: "測試",
            targetText: "Test",
            category: .work
        )
        let event = LearningEvent.sentenceCreated(sentence)

        XCTAssertEqual(event.sentenceID, sentence.id)
        XCTAssertEqual(event.eventType, .sentenceCreated)
        XCTAssertTrue(event.metadataJSON.contains("work"))
    }

    func testListenCompletedFactory() {
        let sentenceID = UUID()
        let event = LearningEvent.listenCompleted(sentenceID)

        XCTAssertEqual(event.sentenceID, sentenceID)
        XCTAssertEqual(event.eventType, .listenCompleted)
    }

    func testPracticeRatedFactory() {
        let sentenceID = UUID()
        let event = LearningEvent.practiceRated(sentenceID, signal: .clear)

        XCTAssertEqual(event.sentenceID, sentenceID)
        XCTAssertEqual(event.eventType, .practiceRated)
        XCTAssertTrue(event.metadataJSON.contains("clear"))
    }

    func testPracticeRatedFactoryAllSignals() {
        for signal in [RecallSignal.clear, .almost, .failed] {
            let event = LearningEvent.practiceRated(UUID(), signal: signal)
            XCTAssertEqual(event.eventType, .practiceRated)
            XCTAssertTrue(event.metadataJSON.contains(signal.rawValue))
        }
    }

    func testPreviewCompletedFactory() {
        let event = LearningEvent.previewCompleted()

        XCTAssertEqual(event.eventType, .previewCompleted)
        XCTAssertNil(event.sentenceID)
    }

    func testVocabAddedFactory() {
        let sentenceID = UUID()
        let event = LearningEvent.vocabAdded(sentenceID, word: "swamped")

        XCTAssertEqual(event.sentenceID, sentenceID)
        XCTAssertEqual(event.eventType, .vocabAdded)
        XCTAssertTrue(event.metadataJSON.contains("swamped"))
    }

    func testLearningEventTypeFromRawValue() {
        XCTAssertEqual(LearningEventType(rawValue: "sentence_created"), .sentenceCreated)
        XCTAssertEqual(LearningEventType(rawValue: "listen_completed"), .listenCompleted)
        XCTAssertEqual(LearningEventType(rawValue: "practice_rated"), .practiceRated)
        XCTAssertEqual(LearningEventType(rawValue: "preview_completed"), .previewCompleted)
        XCTAssertEqual(LearningEventType(rawValue: "vocab_added"), .vocabAdded)
        XCTAssertEqual(LearningEventType(rawValue: "invalid"), nil)
    }
}
