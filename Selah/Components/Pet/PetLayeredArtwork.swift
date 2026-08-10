import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Platform-agnostic image wrapper so the sprite renders on both iOS and macOS.
enum PetPlatformImage {
    #if canImport(UIKit)
    case uiImage(UIImage)
    #elseif canImport(AppKit)
    case nsImage(NSImage)
    #endif

    static func load(named name: String) -> PetPlatformImage? {
        #if canImport(UIKit)
        return UIImage(named: name).map(PetPlatformImage.uiImage)
        #elseif canImport(AppKit)
        return NSImage(named: name).map(PetPlatformImage.nsImage)
        #endif
    }
}

/// Static layered artwork for the seed companion.
///
/// The body is a baked 2.5D pose (240x288 @1x). Eyes are separate overlay
/// layers aligned to the body sheet coordinates so blink can cross-fade
/// without regenerating the body bitmap. Shadow and status glow stay native.
enum PetLayeredPose: String, CaseIterable {
    case neutral
    case float
    case listenEnter = "listen-enter"
    case listenPlaying = "listen-playing"
    case listenComplete = "listen-complete"
    case quizGood = "quiz-good"
    case quizFail = "quiz-fail"
    case recRecording = "rec-recording"
    case recDone = "rec-done"

    var imageName: String {
        switch self {
        case .neutral: return "SeedBodyNeutral"
        case .float: return "SeedBodyFloat"
        case .listenEnter: return "SeedBodyListenEnter"
        case .listenPlaying: return "SeedBodyListenPlaying"
        case .listenComplete: return "SeedBodyListenComplete"
        case .quizGood: return "SeedBodyQuizGood"
        case .quizFail: return "SeedBodyQuizFail"
        case .recRecording: return "SeedBodyRecRecording"
        case .recDone: return "SeedBodyRecDone"
        }
    }

    static func pose(for animationID: PetAnimationID) -> PetLayeredPose {
        switch animationID {
        case .gentleFloat: return .float
        case .blink, .leafSway: return .neutral
        case .listenEnter: return .listenEnter
        case .listenPlaying: return .listenPlaying
        case .listenComplete: return .listenComplete
        case .quizGood: return .quizGood
        case .quizFail: return .quizFail
        case .recRecording: return .recRecording
        case .recDone: return .recDone
        }
    }
}

enum PetEyeState: Equatable {
    case open
    case closed
    case soft

    var overlayImageName: String? {
        switch self {
        case .open: return nil
        case .closed: return "SeedEyesClosed"
        case .soft: return "SeedEyesSoft"
        }
    }
}

struct PetLayeredSpriteConfig {
    var pose: PetLayeredPose = .neutral
    var eyeState: PetEyeState = .open
    var eyeOverlayOpacity: Double = 0
    var shadowScale: CGFloat = 1
    var shadowOpacity: Double = 0.14

    static func reduced(for animationID: PetAnimationID) -> PetLayeredSpriteConfig {
        let eyeState = PetLayeredArtworkMapping.eyeState(for: animationID)
        return PetLayeredSpriteConfig(
            pose: PetLayeredArtworkMapping.pose(for: animationID),
            eyeState: eyeState,
            eyeOverlayOpacity: eyeState == .open ? 0 : 1,
            shadowScale: 1,
            shadowOpacity: 0.14
        )
    }

    static func config(for animationID: PetAnimationID, phase: Double) -> PetLayeredSpriteConfig {
        let pulse = sin(.pi * phase)
        switch animationID {
        case .blink:
            return PetLayeredSpriteConfig(
                pose: .neutral,
                eyeState: .closed,
                eyeOverlayOpacity: pulse,
                shadowScale: 1,
                shadowOpacity: 0.14
            )
        case .gentleFloat:
            return PetLayeredSpriteConfig(
                pose: .float,
                shadowScale: 1 - (0.10 * pulse),
                shadowOpacity: 0.14 - (0.04 * pulse)
            )
        case .listenPlaying:
            return PetLayeredSpriteConfig(
                pose: .listenPlaying,
                shadowScale: 0.96,
                shadowOpacity: 0.12
            )
        case .listenComplete:
            return PetLayeredSpriteConfig(
                pose: .listenComplete,
                shadowScale: 0.86,
                shadowOpacity: 0.10
            )
        case .quizGood:
            return PetLayeredSpriteConfig(
                pose: .quizGood,
                shadowScale: 0.74,
                shadowOpacity: 0.08
            )
        case .quizFail:
            return PetLayeredSpriteConfig(
                pose: .quizFail,
                eyeState: .soft,
                eyeOverlayOpacity: pulse,
                shadowScale: 1.08,
                shadowOpacity: 0.16
            )
        case .recDone:
            return PetLayeredSpriteConfig(
                pose: .recDone,
                eyeState: .soft,
                eyeOverlayOpacity: pulse,
                shadowScale: 0.86,
                shadowOpacity: 0.10
            )
        default:
            return PetLayeredSpriteConfig(pose: PetLayeredPose.pose(for: animationID))
        }
    }
}

/// Pure, testable mapping between animation state and layered artwork input.
enum PetLayeredArtworkMapping {
    static func pose(for animationID: PetAnimationID) -> PetLayeredPose {
        PetLayeredPose.pose(for: animationID)
    }

    static func eyeState(for animationID: PetAnimationID) -> PetEyeState {
        switch animationID {
        case .blink:
            return .closed
        case .quizFail, .recDone:
            return .soft
        default:
            return .open
        }
    }
}

struct PetLayeredSpriteView: View {
    let animationID: PetAnimationID
    var phase: Double = 0
    var reduceMotion = false

    private let bodyImage: PetPlatformImage?
    private let eyeOverlayImage: PetPlatformImage?

    init(
        animationID: PetAnimationID,
        phase: Double = 0,
        reduceMotion: Bool = false,
        bodyImage: PetPlatformImage? = nil,
        eyeOverlayImage: PetPlatformImage? = nil
    ) {
        self.animationID = animationID
        self.phase = phase
        self.reduceMotion = reduceMotion
        self.bodyImage = bodyImage
        self.eyeOverlayImage = eyeOverlayImage
    }

    var body: some View {
        ZStack {
            softShadow
            bodyLayer
            eyeOverlayLayer
        }
        .frame(width: 100, height: 120)
        .selahDecorativeAccessibility()
    }

    private var config: PetLayeredSpriteConfig {
        reduceMotion
            ? PetLayeredSpriteConfig.reduced(for: animationID)
            : PetLayeredSpriteConfig.config(for: animationID, phase: phase)
    }

    private var softShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(config.shadowOpacity))
            .frame(width: 52, height: 10)
            .offset(y: 29)
            .scaleEffect(config.shadowScale)
    }

    @ViewBuilder
    private var bodyLayer: some View {
        let image = bodyImage ?? PetPlatformImage.load(named: config.pose.imageName)
        if let image {
            platformImage(image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 100, height: 120)
        }
    }

    @ViewBuilder
    private var eyeOverlayLayer: some View {
        if config.eyeState != .open,
           config.eyeOverlayOpacity > 0,
           let overlayName = config.eyeState.overlayImageName {
            let image = eyeOverlayImage ?? PetPlatformImage.load(named: overlayName)
            if let image {
                platformImage(image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(config.eyeOverlayOpacity)
                    .frame(width: eyesLayerSize.width, height: eyesLayerSize.height)
                    .position(eyesLayerAnchor)
            }
        }
    }

    /// Eye layer geometry inside the 100x120pt sprite frame.
    /// Source sheet cell is 720x864 units; the eye region starts at (265, 370)
    /// and is 190x65 units (from the exported eyes asset).
    private var eyesLayerSize: CGSize {
        CGSize(width: 100 * 190 / 720, height: 120 * 65 / 864)
    }

    private var eyesLayerAnchor: CGPoint {
        CGPoint(
            x: 100 * (265 + 190 / 2) / 720,
            y: 120 * (370 + 65 / 2) / 864
        )
    }

    private func platformImage(_ image: PetPlatformImage) -> Image {
        switch image {
        #if canImport(UIKit)
        case .uiImage(let uiImage):
            return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        case .nsImage(let nsImage):
            return Image(nsImage: nsImage)
        #endif
        }
    }
}

/// Native status ring used by Listen / Recording / completion states.
/// Painted by SwiftUI so it fades with the state and respects Reduce Motion.
struct PetStatusGlowView: View {
    let animationID: PetAnimationID
    var phase: Double = 0
    var reduceMotion = false

    var body: some View {
        if let color = glowColor, opacity > 0 {
            Circle()
                .stroke(color.opacity(opacity), lineWidth: 3)
                .frame(width: 58, height: 58)
                .shadow(color: color.opacity(opacity * 0.35), radius: 10)
                .allowsHitTesting(false)
        }
    }

    private var glowColor: Color? {
        switch animationID {
        case .listenEnter, .listenPlaying, .listenComplete:
            return .selahLavender
        case .recRecording, .recDone:
            return .selahCoral
        case .quizGood, .quizFail:
            return .selahSage
        default:
            return nil
        }
    }

    private var opacity: Double {
        let pulse = sin(.pi * phase)
        switch animationID {
        case .listenEnter, .recRecording:
            return reduceMotion ? 0.20 : 0.20 + (0.10 * pulse)
        case .listenPlaying:
            return reduceMotion ? 0.22 : 0.22 + (0.08 * pulse)
        case .listenComplete:
            return reduceMotion ? 0.18 : 0.30 * (1 - pulse)
        case .recDone:
            return reduceMotion ? 0.18 : 0.28 * (1 - pulse)
        case .quizGood:
            return reduceMotion ? 0.16 : 0.26 * (1 - pulse)
        case .quizFail:
            return reduceMotion ? 0.12 : 0.20 * (1 - pulse)
        default:
            return 0
        }
    }
}
