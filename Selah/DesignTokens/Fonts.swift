import SwiftUI

// MARK: - Design Tokens: Typography
// Based on selah-ios-design-spec.md
// Primary font: Plus Jakarta Sans

extension Font {

    // Display
    static let selahDisplayLarge  = Font.custom("PlusJakartaSans-ExtraBold", size: 30)
    static let selahDisplayMedium = Font.custom("PlusJakartaSans-Bold", size: 22)

    // Headline
    static let selahHeadlineLarge  = Font.custom("PlusJakartaSans-Bold", size: 18)
    static let selahHeadlineMedium = Font.custom("PlusJakartaSans-SemiBold", size: 15)
    static let selahHeadlineSmall  = Font.custom("PlusJakartaSans-SemiBold", size: 13)

    // Body
    static let selahBodyLarge  = Font.custom("PlusJakartaSans-Regular", size: 14)
    static let selahBodyMedium = Font.custom("PlusJakartaSans-Regular", size: 12)
    static let selahBodySmall  = Font.custom("PlusJakartaSans-Regular", size: 11)

    // Label
    static let selahLabelLarge  = Font.custom("PlusJakartaSans-SemiBold", size: 12)
    static let selahLabelMedium = Font.custom("PlusJakartaSans-SemiBold", size: 10)
    static let selahLabelSmall  = Font.custom("PlusJakartaSans-SemiBold", size: 9)

    // Mono
    static let selahMonoMedium = Font.custom("JetBrainsMono-Medium", size: 11)
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
