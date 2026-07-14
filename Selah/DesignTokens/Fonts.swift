import SwiftUI

// MARK: - Design Tokens: Typography
// Based on selah-ios-design-spec.md
// Primary font: Plus Jakarta Sans

extension Font {

    // Display
    // Custom fonts use fixed design sizes today; callers should apply Dynamic Type
    // through `.dynamicTypeSize(...)` or replace with a scaled system font in iOS UI targets.
    static let selahDisplayLarge  = Font.custom("PlusJakartaSans-ExtraBold", size: 30, relativeTo: .largeTitle)
    static let selahDisplayMedium = Font.custom("PlusJakartaSans-Bold", size: 22, relativeTo: .title)

    // Headline
    static let selahHeadlineLarge  = Font.custom("PlusJakartaSans-Bold", size: 18, relativeTo: .headline)
    static let selahHeadlineMedium = Font.custom("PlusJakartaSans-SemiBold", size: 15, relativeTo: .subheadline)
    static let selahHeadlineSmall  = Font.custom("PlusJakartaSans-SemiBold", size: 13, relativeTo: .subheadline)

    // Body
    static let selahBodyLarge  = Font.custom("PlusJakartaSans-Regular", size: 14, relativeTo: .body)
    static let selahBodyMedium = Font.custom("PlusJakartaSans-Regular", size: 12, relativeTo: .caption)
    static let selahBodySmall  = Font.custom("PlusJakartaSans-Regular", size: 11, relativeTo: .caption2)

    // Label
    static let selahLabelLarge  = Font.custom("PlusJakartaSans-SemiBold", size: 12, relativeTo: .caption)
    static let selahLabelMedium = Font.custom("PlusJakartaSans-SemiBold", size: 10, relativeTo: .caption2)
    static let selahLabelSmall  = Font.custom("PlusJakartaSans-SemiBold", size: 9, relativeTo: .caption2)

    // Mono
    static let selahMonoMedium = Font.custom("JetBrainsMono-Medium", size: 11, relativeTo: .body)
}

// MARK: - Text Style Modifiers

extension View {
    func selahDisplayLarge() -> some View {
        self.font(.selahDisplayLarge)
            .foregroundColor(.selahTextPrimary)
    }

    func selahHeadlineLarge() -> some View {
        self.font(.selahHeadlineLarge)
            .foregroundColor(.selahTextPrimary)
    }

    func selahHeadlineMedium() -> some View {
        self.font(.selahHeadlineMedium)
            .foregroundColor(.selahTextPrimary)
    }

    func selahHeadlineSmall() -> some View {
        self.font(.selahHeadlineSmall)
            .foregroundColor(.selahTextSecondary)
    }

    func selahBodyLarge() -> some View {
        self.font(.selahBodyLarge)
            .foregroundColor(.selahTextPrimary)
    }

    func selahBodyMedium() -> some View {
        self.font(.selahBodyMedium)
            .foregroundColor(.selahTextSecondary)
    }

    func selahBodySmall() -> some View {
        self.font(.selahBodySmall)
            .foregroundColor(.selahTextTertiary)
    }

    func selahLabelLarge() -> some View {
        self.font(.selahLabelLarge)
            .foregroundColor(.selahTextSecondary)
    }

    func selahLabelSmall() -> some View {
        self.font(.selahLabelSmall)
            .foregroundColor(.selahTextTertiary)
    }
}
