import XCTest
@testable import Selah

final class LearningCapturePreprocessorTests: XCTestCase {
    private let preprocessor = LearningCapturePreprocessor()

    func testRemovesOnlyLeadingDisfluencyAndPreservesMeaningfulParticles() {
        let result = preprocessor.prepare(
            transcript: "呃，我今天開會開了很久。那個方案比較好啊。"
        )

        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].sourceText, "我今天開會開了很久。")
        XCTAssertEqual(result.segments[0].removedText, ["呃"])
        XCTAssertEqual(result.segments[1].sourceText, "那個方案比較好啊。")
        XCTAssertTrue(result.segments[1].removedText.isEmpty)
    }

    func testLimitsDefaultSelectionWithoutDroppingSegments() {
        let result = preprocessor.prepare(
            transcript: "第一句。第二句。第三句。第四句。第五句。第六句。"
        )

        XCTAssertEqual(result.segments.count, 6)
        XCTAssertEqual(result.segments.filter(\.selected).count, 5)
        XCTAssertEqual(result.segments.map(\.orderIndex), Array(0..<6))
    }

    func testKeepsUnpunctuatedLongTranscriptAsOneEditableSegment() {
        let result = preprocessor.prepare(transcript: "我今天有很多事情想跟你說")

        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments[0].sourceText, "我今天有很多事情想跟你說")
    }
}
