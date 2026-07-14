import Foundation
import SwiftUI

/// Motion policy kept separate from SwiftUI so animation choices remain testable.
enum SelahMotionPolicy: Equatable, Sendable {
    case standard
    case reduced

    var allowsAnimation: Bool { self == .standard }

    static func policy(reduceMotion: Bool) -> SelahMotionPolicy {
        reduceMotion ? .reduced : .standard
    }
}

extension View {
    /// Applies a semantic label and optional hint without replacing the view's visible text.
    func selahAccessibility(label: String, hint: String? = nil, value: String? = nil) -> some View {
        accessibilityLabel(Text(label))
            .accessibilityHint(Text(hint ?? ""))
            .accessibilityValue(Text(value ?? ""))
    }

    /// Makes a visual-only decoration invisible to VoiceOver.
    func selahDecorativeAccessibility() -> some View {
        accessibilityHidden(true)
    }

    /// Uses no animation when Reduce Motion is enabled.
    @ViewBuilder
    func selahMotion(_ policy: SelahMotionPolicy, animation: Animation = .default) -> some View {
        if policy.allowsAnimation {
            self.animation(animation, value: policy.allowsAnimation)
        } else {
            self.animation(nil, value: policy.allowsAnimation)
        }
    }
}

/// WCAG 2.1 contrast helpers for design-token review and unit tests.
enum SelahContrast {
    static func ratio(foregroundHex: String, backgroundHex: String) -> Double? {
        guard let foreground = rgb(foregroundHex), let background = rgb(backgroundHex) else { return nil }
        let foregroundLuminance = luminance(foreground)
        let backgroundLuminance = luminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func meetsNormalText(foregroundHex: String, backgroundHex: String) -> Bool {
        guard let ratio = ratio(foregroundHex: foregroundHex, backgroundHex: backgroundHex) else { return false }
        return ratio >= 4.5
    }

    static func meetsLargeText(foregroundHex: String, backgroundHex: String) -> Bool {
        guard let ratio = ratio(foregroundHex: foregroundHex, backgroundHex: backgroundHex) else { return false }
        return ratio >= 3.0
    }

    private static func rgb(_ value: String) -> (Double, Double, Double)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard hex.count == 6, let integer = UInt64(hex, radix: 16) else { return nil }
        return (
            Double((integer >> 16) & 0xFF) / 255,
            Double((integer >> 8) & 0xFF) / 255,
            Double(integer & 0xFF) / 255
        )
    }

    private static func luminance(_ color: (Double, Double, Double)) -> Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(color.0) + 0.7152 * linearize(color.1) + 0.0722 * linearize(color.2)
    }
}
