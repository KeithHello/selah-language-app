import SwiftUI

private struct PetSpritePose {
    var bodyOffset: CGSize = .zero
    var bodyScale: CGSize = CGSize(width: 1, height: 1)
    var bodyRotation: Double = 0
    var eyeScaleY: CGFloat = 1
    var eyeOffset: CGSize = .zero
    var leafRotation: Double = 0
    var leafScale: CGFloat = 1
    var bodyOpacity: Double = 1

    static let neutral = PetSpritePose()
}

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
            PetSpriteArtwork(decorationStage: decorationStage, pose: .neutral)
        } else {
            switch animationID {
            case .gentleFloat:
                PetSpriteArtwork(
                    decorationStage: decorationStage,
                    pose: pose(for: animationID, phase: loopPhase ? 1 : 0)
                )
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: loopPhase)

            case .blink, .listenComplete, .recDone, .quizGood, .quizFail:
                PetSpriteArtwork(
                    decorationStage: decorationStage,
                    pose: pose(for: animationID, phase: oneShotProgress)
                )
                .animation(.easeInOut(duration: PetAnimationDescriptor.descriptor(for: animationID).duration), value: oneShotProgress)

            case .leafSway:
                if PetAnimationAvailability.canTrigger(animationID, decorationStage: decorationStage) {
                    PetSpriteArtwork(
                        decorationStage: decorationStage,
                        pose: pose(for: animationID, phase: loopPhase ? 1 : 0)
                    )
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: loopPhase)
                } else {
                    PetSpriteArtwork(decorationStage: decorationStage, pose: .neutral)
                }

            case .listenEnter, .recRecording, .listenPlaying:
                PetSpriteArtwork(
                    decorationStage: decorationStage,
                    pose: pose(for: animationID, phase: loopPhase ? 1 : 0)
                )
                .animation(.easeInOut(duration: animationDuration(for: animationID)).repeatForever(autoreverses: true), value: loopPhase)
            }
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

    private func pose(for animationID: PetAnimationID, phase: Double) -> PetSpritePose {
        let pulse = sin(.pi * phase)

        switch animationID {
        case .gentleFloat:
            return PetSpritePose(bodyOffset: CGSize(width: 0, height: -4 * phase))
        case .blink:
            return PetSpritePose(eyeScaleY: 1 - (0.9 * pulse))
        case .leafSway:
            return PetSpritePose(leafRotation: 10 * phase)
        case .listenEnter:
            return PetSpritePose(bodyRotation: -12)
        case .listenPlaying:
            return PetSpritePose(
                bodyScale: CGSize(width: 1 - (0.02 * phase), height: 1 + (0.02 * phase))
            )
        case .listenComplete:
            return PetSpritePose(bodyOffset: CGSize(width: 0, height: -5 * pulse))
        case .recRecording:
            return PetSpritePose(bodyRotation: -6, leafRotation: -8)
        case .recDone:
            return PetSpritePose(
                bodyOffset: CGSize(width: 0, height: -6 * pulse),
                eyeScaleY: 0.7 + (0.3 * (1 - pulse)),
                leafRotation: -20 * pulse
            )
        case .quizGood:
            return PetSpritePose(
                bodyOffset: CGSize(width: 0, height: -10 * pulse),
                bodyRotation: 20 * pulse,
                leafRotation: 14 * sin(.pi * phase * 3)
            )
        case .quizFail:
            return PetSpritePose(
                bodyOffset: CGSize(width: 0, height: 5 * pulse),
                eyeScaleY: 1 - (0.7 * pulse),
                leafRotation: -18 * pulse
            )
        }
    }
}

private struct PetSpriteArtwork: View {
    let decorationStage: DecorationStage
    let pose: PetSpritePose

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 52, height: 10)
                .offset(y: 29)

            spriteBody
                .offset(pose.bodyOffset)
                .scaleEffect(pose.bodyScale)
                .rotationEffect(.degrees(pose.bodyRotation))
                .opacity(pose.bodyOpacity)

            decorationView
                .offset(y: -38)
                .rotationEffect(.degrees(pose.leafRotation))
                .scaleEffect(pose.leafScale)
        }
    }

    private var spriteBody: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.selahAmber, Color.selahAmber.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)

            HStack(spacing: 16) {
                Circle()
                    .fill(Color.selahTextPrimary)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.selahTextPrimary)
                    .frame(width: 6, height: 6)
            }
            .scaleEffect(y: pose.eyeScaleY)
            .offset(pose.eyeOffset)

            PetSmileArc()
                .stroke(Color.selahTextPrimary, lineWidth: 2)
                .frame(width: 20, height: 10)
                .offset(y: 6)

            HStack(spacing: 36) {
                Circle().fill(Color.selahCoral.opacity(0.15)).frame(width: 8, height: 6)
                Circle().fill(Color.selahCoral.opacity(0.15)).frame(width: 8, height: 6)
            }
            .offset(y: 10)
        }
    }

    @ViewBuilder
    private var decorationView: some View {
        switch decorationStage {
        case .none:
            EmptyView()
        case .sprout:
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(.selahSage)
        case .leaf:
            Image(systemName: "leaf.fill")
                .font(.system(size: 18))
                .foregroundColor(.selahSage)
        case .bud:
            HStack(spacing: 0) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.selahSage)
                Circle()
                    .fill(Color.selahRose.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(x: -2, y: -4)
            }
        case .bloom:
            HStack(spacing: 0) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.selahSage)
                Image(systemName: "flower")
                    .font(.system(size: 14))
                    .foregroundColor(.selahCoral)
                    .offset(x: -2, y: -4)
            }
        }
    }
}

private struct PetSmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(20),
            endAngle: .degrees(160),
            clockwise: false
        )
        return path
    }
}
