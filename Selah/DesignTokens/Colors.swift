import SwiftUI

// MARK: - Design Tokens: Colors
// Based on selah-ios-design-spec.md

extension Color {

    // Background
    static let selahBgPrimary    = Color(hex: "#FBF8F4")
    static let selahBgSecondary  = Color(hex: "#F8F5F0")
    static let selahCardPrimary  = Color(hex: "#FFFFFF")

    // Text
    static let selahTextPrimary   = Color(hex: "#1A1614")
    static let selahTextSecondary = Color(hex: "#706B65")
    static let selahTextTertiary  = Color(hex: "#A9A49E")

    // Border
    static let selahBorder       = Color(hex: "#EBE7E1")
    static let selahBorderLight  = Color(hex: "#F3F0EC")

    // Accent
    static let selahCoral        = Color(hex: "#E06B54")
    static let selahCoralSoft    = Color(hex: "#FEF0ED")
    static let selahSage         = Color(hex: "#5A9E82")
    static let selahSageSoft     = Color(hex: "#ECF7F1")
    static let selahAmber        = Color(hex: "#E5A244")
    static let selahAmberSoft    = Color(hex: "#FDF5E6")
    static let selahLavender     = Color(hex: "#8B7FC7")
    static let selahLavenderSoft = Color(hex: "#F0EEF8")
    static let selahSky          = Color(hex: "#5B9FD4")
    static let selahSkySoft      = Color(hex: "#EAF3FB")
    static let selahRose         = Color(hex: "#D4829C")
    static let selahRoseSoft     = Color(hex: "#F9EEF2")

    // Semantic aliases
    static let selahSuccess   = selahSage
    static let selahWarning   = selahAmber
    static let selahDanger    = selahCoral
    static let selahInfo      = selahSky
    static let selahListen    = selahLavender

    // MARK: - Hex initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
