import XCTest
@testable import Selah

final class VoiceProfilePickerTests: XCTestCase {

    func testVoiceProfile_allCases_hasFour() {
        XCTAssertEqual(VoiceProfile.allCases.count, 4)
    }

    func testVoiceProfile_displayNames() {
        XCTAssertEqual(VoiceProfile.gentleNatural.displayName, "溫柔自然")
        XCTAssertEqual(VoiceProfile.clearSlow.displayName, "清晰慢速")
        XCTAssertEqual(VoiceProfile.dailyBright.displayName, "日常輕快")
        XCTAssertEqual(VoiceProfile.elegantBritish.displayName, "優雅英式")
    }

    func testVoiceProfile_descriptions_nonEmpty() {
        for voice in VoiceProfile.allCases {
            XCTAssertFalse(voice.description.isEmpty, "\(voice) has empty description")
        }
    }

    func testVoiceProfile_isDefault() {
        XCTAssertTrue(VoiceProfile.gentleNatural.isDefault)
        XCTAssertTrue(VoiceProfile.clearSlow.isDefault)
        XCTAssertTrue(VoiceProfile.dailyBright.isDefault)
        XCTAssertFalse(VoiceProfile.elegantBritish.isDefault)
    }

    func testVoiceProfile_rawValues() {
        XCTAssertEqual(VoiceProfile.gentleNatural.rawValue, "gentle-natural")
        XCTAssertEqual(VoiceProfile.clearSlow.rawValue, "clear-slow")
        XCTAssertEqual(VoiceProfile.dailyBright.rawValue, "daily-bright")
        XCTAssertEqual(VoiceProfile.elegantBritish.rawValue, "elegant-british")
    }

    func testVoiceProfile_codable() throws {
        let voice = VoiceProfile.elegantBritish
        let data = try JSONEncoder().encode(voice)
        let decoded = try JSONDecoder().decode(VoiceProfile.self, from: data)
        XCTAssertEqual(voice, decoded)
    }

    func testVoiceProfile_initFromRawValue() {
        XCTAssertEqual(VoiceProfile(rawValue: "gentle-natural"), .gentleNatural)
        XCTAssertEqual(VoiceProfile(rawValue: "clear-slow"), .clearSlow)
        XCTAssertEqual(VoiceProfile(rawValue: "daily-bright"), .dailyBright)
        XCTAssertEqual(VoiceProfile(rawValue: "elegant-british"), .elegantBritish)
        XCTAssertNil(VoiceProfile(rawValue: "unknown"))
    }
}

final class TodaySentenceFlowStateTests: XCTestCase {

    func testFlowState_equality() {
        XCTAssertEqual(TodaySentenceFlowState.idle, .idle)
        XCTAssertEqual(TodaySentenceFlowState.recording, .recording)
        XCTAssertEqual(TodaySentenceFlowState.translating, .translating)
        XCTAssertEqual(TodaySentenceFlowState.saving, .saving)
        XCTAssertEqual(TodaySentenceFlowState.done, .done)
        XCTAssertNotEqual(TodaySentenceFlowState.idle, .recording)
    }

    func testFlowState_confirmingChinese_carriesTranscript() {
        let state = TodaySentenceFlowState.confirmingChinese(transcript: "今天好累")
        if case .confirmingChinese(let transcript) = state {
            XCTAssertEqual(transcript, "今天好累")
        } else {
            XCTFail("Expected confirmingChinese state")
        }
    }

    func testFlowState_reviewingResult_carriesResult() {
        let result = GeneratedSentenceResult(
            targetText: "I'm tired today",
            category: .work,
            vocabulary: [],
            deconstruction: [],
            promptVersion: "v8.0"
        )
        let state = TodaySentenceFlowState.reviewingResult(result: result)
        if case .reviewingResult(let extracted) = state {
            XCTAssertEqual(extracted.targetText, "I'm tired today")
        } else {
            XCTFail("Expected reviewingResult state")
        }
    }

    func testFlowState_error_carriesMessage() {
        let state = TodaySentenceFlowState.error(message: "Network failed")
        if case .error(let message) = state {
            XCTAssertEqual(message, "Network failed")
        } else {
            XCTFail("Expected error state")
        }
    }
}
