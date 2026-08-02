import XCTest
@testable import Selah

final class PetLayeredArtworkMappingTests: XCTestCase {
    func testEveryPilotAnimationHasALayeredPose() {
        for animation in PetAnimationID.allCases {
            XCTAssertNotNil(
                PetLayeredPose.pose(for: animation).imageName,
                "Missing pose mapping for \(animation.rawValue)"
            )
        }
    }

    func testBlinkUsesClosedEyesOverlay() {
        XCTAssertEqual(
            PetLayeredArtworkMapping.eyeState(for: .blink),
            .closed
        )
        XCTAssertNotNil(PetLayeredArtworkMapping.eyeState(for: .blink).overlayImageName)
    }

    func testNonBlinkAnimationsKeepOpenEyes() {
        for animation in PetAnimationID.allCases where animation != .blink {
            XCTAssertEqual(
                PetLayeredArtworkMapping.eyeState(for: animation),
                .open,
                "Unexpected eye state for \(animation.rawValue)"
            )
        }
    }

    func testPoseConfigMatchesAnimationSemantics() {
        XCTAssertEqual(PetLayeredPose.pose(for: .gentleFloat), .float)
        XCTAssertEqual(PetLayeredPose.pose(for: .listenEnter), .listenEnter)
        XCTAssertEqual(PetLayeredPose.pose(for: .quizFail), .quizFail)
        XCTAssertEqual(PetLayeredPose.pose(for: .recDone), .recDone)
    }

    func testBlinkConfigFadesEyesWithPhase() {
        let closed = PetLayeredSpriteConfig.config(for: .blink, phase: 0.5)
        XCTAssertEqual(closed.eyeState, .closed)
        XCTAssertGreaterThan(closed.eyeOverlayOpacity, 0.9)

        let open = PetLayeredSpriteConfig.config(for: .blink, phase: 0)
        XCTAssertLessThanOrEqual(open.eyeOverlayOpacity, 0.01)
    }

    func testReducedMotionConfigUsesStaticPose() {
        let reduced = PetLayeredSpriteConfig(
            pose: PetLayeredArtworkMapping.pose(for: .quizGood)
        )
        XCTAssertEqual(reduced.pose, .quizGood)
        XCTAssertEqual(reduced.eyeOverlayOpacity, 0)
        XCTAssertEqual(reduced.shadowScale, 1)
    }
}
