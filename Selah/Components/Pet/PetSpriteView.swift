import SwiftUI

/// Compact reusable sprite renderer. It contains no business state and is
/// driven only by PetAnimationController plus the companion decoration stage.
struct PetSpriteView: View {
    @ObservedObject var animationController: PetAnimationController
    let decorationStage: DecorationStage
    private let requestedReduceMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var loopPhase = false
    @State private var oneShotProgress = 0.0

    init(
        animationController: PetAnimationController,
        decorationStage: DecorationStage,
        reduceMotion: Bool = false
    ) {
        self.animationController = animationController
        self.decorationStage = decorationStage
        self.requestedReduceMotion = reduceMotion
    }

    private var reduceMotion: Bool {
        requestedReduceMotion || accessibilityReduceMotion
    }

    var body: some View {
        animatedArtwork
            .frame(width: 100, height: 120)
            .selahDecorativeAccessibility()
            .onAppear {
                startAnimation(for: animationController.activeID)
            }
            .onChange(of: animationController.activeID) { _, animationID in
                startAnimation(for: animationID)
            }
            .task(id: animationController.state.transientID) {
                guard let transientID = animationController.state.transientID else { return }
                let descriptor = PetAnimationDescriptor.descriptor(for: transientID)
                guard descriptor.playback == .oneShot, descriptor.duration > 0 else { return }
                let nanoseconds = UInt64(descriptor.duration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                animationController.finishTransient()
            }
    }

    @ViewBuilder
    private var animatedArtwork: some View {
        let animationID = animationController.activeID

        if reduceMotion {
            layeredArtwork(for: animationID, phase: 0)
        } else {
            switch animationID {
            case .gentleFloat:
                layeredArtwork(for: animationID, phase: loopPhase ? 1 : 0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: loopPhase)

            case .blink, .listenComplete, .recDone, .quizGood, .quizFail:
                layeredArtwork(for: animationID, phase: oneShotProgress)
                .animation(.easeInOut(duration: PetAnimationDescriptor.descriptor(for: animationID).duration), value: oneShotProgress)

            case .leafSway:
                if PetAnimationAvailability.canTrigger(animationID, decorationStage: decorationStage) {
                    layeredArtwork(for: animationID, phase: loopPhase ? 1 : 0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: loopPhase)
                } else {
                    layeredArtwork(for: animationID, phase: 0)
                }

            case .listenEnter, .recRecording, .listenPlaying:
                layeredArtwork(for: animationID, phase: loopPhase ? 1 : 0)
                .animation(.easeInOut(duration: animationDuration(for: animationID)).repeatForever(autoreverses: true), value: loopPhase)
            }
        }
    }

    /// Layered static artwork with native decoration overlay.
    @ViewBuilder
    private func layeredArtwork(for animationID: PetAnimationID, phase: Double) -> some View {
        ZStack {
            PetLayeredSpriteView(
                animationID: animationID,
                phase: phase,
                reduceMotion: reduceMotion
            )
            PetStatusGlowView(animationID: animationID, phase: phase, reduceMotion: reduceMotion)
            decorationView
                .offset(y: -38)
                .rotationEffect(.degrees(leafRotation(for: animationID, phase: phase)))
        }
    }

    private func leafRotation(for animationID: PetAnimationID, phase: Double) -> Double {
        let pulse = sin(.pi * phase)
        switch animationID {
        case .leafSway:
            return 10 * phase
        case .listenEnter:
            return -8 * phase
        case .recRecording:
            return -8 * phase
        case .quizGood:
            return 14 * sin(.pi * phase * 3)
        case .quizFail:
            return -18 * pulse
        case .recDone:
            return -20 * pulse
        default:
            return 0
        }
    }

    private var decorationView: some View {
        switch decorationStage {
        case .none:
            return AnyView(EmptyView())
        case .sprout:
            return AnyView(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.selahSage)
            )
        case .leaf:
            return AnyView(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.selahSage)
            )
        case .bud:
            return AnyView(
                HStack(spacing: 0) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.selahSage)
                    Circle()
                        .fill(Color.selahRose.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: -4)
                }
            )
        case .bloom:
            return AnyView(
                HStack(spacing: 0) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.selahSage)
                    Image(systemName: "flower")
                        .font(.system(size: 14))
                        .foregroundColor(.selahCoral)
                        .offset(x: -2, y: -4)
                }
            )
        }
    }

    private func animationDuration(for animationID: PetAnimationID) -> Double {
        switch animationID {
        case .listenPlaying: return 0.12
        case .listenEnter, .recRecording: return 0.5
        default: return 1.5
        }
    }

    private func startAnimation(for animationID: PetAnimationID) {
        loopPhase = false
        oneShotProgress = 0
        guard !reduceMotion else { return }

        switch PetAnimationDescriptor.descriptor(for: animationID).playback {
        case .loop, .hold:
            DispatchQueue.main.async {
                loopPhase = true
            }
        case .oneShot:
            withAnimation(.easeInOut(duration: PetAnimationDescriptor.descriptor(for: animationID).duration)) {
                oneShotProgress = 1
            }
        }
    }
}
