import XCTest
@testable import Selah

final class M3LearningEngineTests: XCTestCase {
    func testRecommendationTypes_haveUserFacingNamesAndReasons() {
        for type in [
            TodayRecommendationType.practice,
            .listen,
            .nightPreview,
            .todaySentence,
            .seedListen
        ] {
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.reasonTemplate.isEmpty)
        }
    }

    func testRecommendationReasonItem_preservesLearningContext() {
        let sentenceID = UUID()
        let item = TodayRecommendation.ReasonItem(
            id: sentenceID,
            sentencePreview: "今天終於準時下班",
            nextState: "現在",
            plainReason: "這句剛好到了回想時間"
        )

        XCTAssertEqual(item.id, sentenceID)
        XCTAssertEqual(item.sentencePreview, "今天終於準時下班")
        XCTAssertEqual(item.nextState, "現在")
        XCTAssertEqual(item.plainReason, "這句剛好到了回想時間")
    }

    func testContextualBridge_supportsLearningTransitions() {
        let suggestions: [ContextualBridge.BridgeSuggestion] = [
            .practice(3),
            .listenMore(3),
            .previewMore(2),
            .recordAnother,
            .stop
        ]

        XCTAssertEqual(suggestions.count, 5)
        if case .practice(let count) = suggestions[0] {
            XCTAssertEqual(count, 3)
        } else {
            XCTFail("Expected practice bridge")
        }
    }
}
