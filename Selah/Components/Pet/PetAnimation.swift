import Combine
import Foundation

/// The ten animation IDs implemented in the first native SwiftUI pilot.
enum PetAnimationID: String, CaseIterable, Codable, Identifiable {
    case gentleFloat = "IDLE-01"
    case blink = "IDLE-09"
    case leafSway = "IDLE-25"
    case listenEnter = "ACT-01"
    case listenPlaying = "ACT-02"
    case listenComplete = "ACT-04"
    case quizGood = "ACT-29"
    case quizFail = "ACT-31"
    case recRecording = "ACT-35"
    case recDone = "ACT-36"

    var id: String { rawValue }
}

enum PetAnimationLayer: Int, Comparable {
    case ambient = 0
    case context = 10
    case reaction = 20

    static func < (lhs: PetAnimationLayer, rhs: PetAnimationLayer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PetAnimationPlayback: Equatable {
    case loop
    case hold
    case oneShot
}

struct PetAnimationDescriptor: Equatable {
    let id: PetAnimationID
    let name: String
    let layer: PetAnimationLayer
    let playback: PetAnimationPlayback
    let duration: TimeInterval

    static func descriptor(for id: PetAnimationID) -> PetAnimationDescriptor {
        switch id {
        case .gentleFloat:
            return PetAnimationDescriptor(id: id, name: "gentle-float", layer: .context, playback: .loop, duration: 3)
        case .blink:
            return PetAnimationDescriptor(id: id, name: "blink", layer: .ambient, playback: .oneShot, duration: 0.3)
        case .leafSway:
            return PetAnimationDescriptor(id: id, name: "leaf-sway", layer: .ambient, playback: .loop, duration: 3)
        case .listenEnter:
            return PetAnimationDescriptor(id: id, name: "listen-enter", layer: .context, playback: .hold, duration: 0)
        case .listenPlaying:
            return PetAnimationDescriptor(id: id, name: "listen-playing", layer: .context, playback: .loop, duration: 0.24)
        case .listenComplete:
            return PetAnimationDescriptor(id: id, name: "listen-complete", layer: .reaction, playback: .oneShot, duration: 0.6)
        case .quizGood:
            return PetAnimationDescriptor(id: id, name: "quiz-good", layer: .reaction, playback: .oneShot, duration: 1.2)
        case .quizFail:
            return PetAnimationDescriptor(id: id, name: "quiz-fail", layer: .reaction, playback: .oneShot, duration: 1.5)
        case .recRecording:
            return PetAnimationDescriptor(id: id, name: "rec-recording", layer: .context, playback: .hold, duration: 0)
        case .recDone:
            return PetAnimationDescriptor(id: id, name: "rec-done", layer: .reaction, playback: .oneShot, duration: 1.5)
        }
    }
}

enum PetAnimationContext: Equatable {
    case idle
    case listenEnter
    case listenPlaying
    case recording

    var animationID: PetAnimationID {
        switch self {
        case .idle: return .gentleFloat
        case .listenEnter: return .listenEnter
        case .listenPlaying: return .listenPlaying
        case .recording: return .recRecording
        }
    }
}

enum PetAnimationEvent: Equatable {
    case setContext(PetAnimationContext)
    case trigger(PetAnimationID)
    case finishTransient
}

struct PetAnimationState: Equatable {
    var context: PetAnimationContext = .idle
    var transientID: PetAnimationID?

    var activeID: PetAnimationID {
        transientID ?? context.animationID
    }
}

enum PetAnimationStateMachine {
    static func reduce(
        _ input: PetAnimationState,
        event: PetAnimationEvent
    ) -> PetAnimationState {
        var state = input

        switch event {
        case .setContext(let context):
            state.context = context
            if let transientID = state.transientID,
               PetAnimationDescriptor.descriptor(for: transientID).layer == .ambient {
                state.transientID = nil
            }

        case .trigger(let animationID):
            let descriptor = PetAnimationDescriptor.descriptor(for: animationID)

            if descriptor.layer == .ambient {
                guard state.context == .idle, state.transientID == nil else { return state }
            } else if descriptor.layer == .reaction {
                if let currentID = state.transientID {
                    let current = PetAnimationDescriptor.descriptor(for: currentID)
                    guard descriptor.layer >= current.layer else { return state }
                }
            } else {
                return state
            }

            state.transientID = animationID

        case .finishTransient:
            state.transientID = nil
        }

        return state
    }
}

enum PetAnimationAvailability {
    static func canTrigger(
        _ animationID: PetAnimationID,
        decorationStage: DecorationStage
    ) -> Bool {
        guard animationID == .leafSway else { return true }
        return decorationStage != .none
    }
}

/// Observable wrapper used by SwiftUI screens. The state machine remains pure
/// so animation priority and recovery can be tested without a UI runtime.
final class PetAnimationController: ObservableObject {
    @Published private(set) var state = PetAnimationState()

    var activeID: PetAnimationID { state.activeID }

    func setContext(_ context: PetAnimationContext) {
        state = PetAnimationStateMachine.reduce(state, event: .setContext(context))
    }

    func trigger(_ animationID: PetAnimationID) {
        state = PetAnimationStateMachine.reduce(state, event: .trigger(animationID))
    }

    func finishTransient() {
        state = PetAnimationStateMachine.reduce(state, event: .finishTransient)
    }
}
