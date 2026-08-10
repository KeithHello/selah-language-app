#if DEBUG
import SwiftUI

/// Debug-only gallery for reviewing the 10 pilot animations at runtime scale.
/// Not reachable from release navigation.
struct PetAnimationGalleryView: View {
    @StateObject private var controller = PetAnimationController()
    @State private var selectedID: PetAnimationID = .gentleFloat
    @State private var decorationStage: DecorationStage = .leaf
    @State private var reduceMotion = false

    var body: some View {
        List {
            Section("Preview") {
                VStack(spacing: 18) {
                    PetSpriteView(
                        animationController: controller,
                        decorationStage: decorationStage,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: 100, height: 120)

                    PetSpriteView(
                        animationController: controller,
                        decorationStage: decorationStage,
                        reduceMotion: reduceMotion
                    )
                    .scaleEffect(2.6)
                    .frame(width: 100, height: 120)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Animation") {
                Picker("Action", selection: $selectedID) {
                    ForEach(PetAnimationID.allCases) { animation in
                        Text("\(animation.rawValue) · \(animation.name)")
                            .tag(animation)
                    }
                }

                Button("Trigger once") {
                    controller.trigger(selectedID)
                }

                Button("Return to idle") {
                    controller.setContext(.idle)
                    controller.finishTransient()
                }
            }

            Section("Environment") {
                Toggle("Reduce Motion", isOn: $reduceMotion)

                Picker("Decoration stage", selection: $decorationStage) {
                    ForEach(DecorationStage.allCases, id: \.self) { stage in
                        Text(stage.label).tag(stage)
                    }
                }
            }
        }
        .navigationTitle("Pet Animation Gallery")
        .onChange(of: selectedID) { _, animationID in
            switch animationID {
            case .gentleFloat, .leafSway, .listenEnter, .listenPlaying, .recRecording:
                controller.setContext(context(for: animationID))
            default:
                controller.setContext(.idle)
                controller.trigger(animationID)
            }
        }
        .onChange(of: decorationStage) { _, stage in
            controller.setContext(.idle)
            if stage != .none {
                controller.trigger(.leafSway)
            }
        }
    }

    private func context(for animationID: PetAnimationID) -> PetAnimationContext {
        switch animationID {
        case .listenEnter, .listenPlaying:
            return .listenEnter
        case .recRecording:
            return .recording
        default:
            return .idle
        }
    }
}

private extension DecorationStage {
    var label: String {
        switch self {
        case .none: return "None"
        case .sprout: return "Sprout"
        case .leaf: return "Leaf"
        case .bud: return "Bud"
        case .bloom: return "Bloom"
        }
    }
}

private extension PetAnimationID {
    var name: String {
        PetAnimationDescriptor.descriptor(for: self).name
    }
}

#Preview {
    NavigationStack {
        PetAnimationGalleryView()
    }
}
#endif
