import XCTest
@testable import Selah

final class PetAnimationRegistryTests: XCTestCase {
    func testPilotRegistryContainsExactlyTenAnimations() {
        XCTAssertEqual(PetAnimationID.allCases.count, 10)
        XCTAssertEqual(PetAnimationID.allCases.map(\.rawValue), [
            "IDLE-01", "IDLE-09", "IDLE-25",
            "ACT-01", "ACT-02", "ACT-04",
            "ACT-29", "ACT-31", "ACT-35", "ACT-36"
        ])
    }

    func testEveryPilotAnimationHasDescriptor() {
        for animation in PetAnimationID.allCases {
            let descriptor = PetAnimationDescriptor.descriptor(for: animation)
            XCTAssertFalse(descriptor.name.isEmpty)
            XCTAssertGreaterThanOrEqual(descriptor.duration, 0)
        }
    }
}

final class PetAnimationStateMachineTests: XCTestCase {
    func testContextChangeSelectsContextAnimation() {
        let state = PetAnimationStateMachine.reduce(
            PetAnimationState(),
            event: .setContext(.listenPlaying)
        )

        XCTAssertEqual(state.activeID, .listenPlaying)
        XCTAssertNil(state.transientID)
    }

    func testReactionOverridesContextAndFinishesBackToContext() {
        var state = PetAnimationStateMachine.reduce(
            PetAnimationState(),
            event: .setContext(.listenPlaying)
        )
        state = PetAnimationStateMachine.reduce(state, event: .trigger(.listenComplete))

        XCTAssertEqual(state.activeID, .listenComplete)
        XCTAssertEqual(state.transientID, .listenComplete)

        state = PetAnimationStateMachine.reduce(state, event: .finishTransient)
        XCTAssertEqual(state.activeID, .listenPlaying)
        XCTAssertNil(state.transientID)
    }

    func testAmbientAnimationIsIgnoredOutsideIdle() {
        var state = PetAnimationStateMachine.reduce(
            PetAnimationState(),
            event: .setContext(.recording)
        )
        state = PetAnimationStateMachine.reduce(state, event: .trigger(.blink))

        XCTAssertEqual(state.activeID, .recording)
        XCTAssertNil(state.transientID)
    }

    func testReactionReplacesAmbientAnimation() {
        var state = PetAnimationStateMachine.reduce(PetAnimationState(), event: .trigger(.blink))
        XCTAssertEqual(state.activeID, .blink)

        state = PetAnimationStateMachine.reduce(state, event: .trigger(.quizGood))
        XCTAssertEqual(state.activeID, .quizGood)
        XCTAssertEqual(state.transientID, .quizGood)
    }

    func testLeafSwayRequiresAVisibleDecoration() {
        XCTAssertFalse(
            PetAnimationAvailability.canTrigger(
                .leafSway,
                decorationStage: .none
            )
        )
        XCTAssertTrue(
            PetAnimationAvailability.canTrigger(
                .leafSway,
                decorationStage: .sprout
            )
        )
    }
}
