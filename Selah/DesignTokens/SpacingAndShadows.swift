import SwiftUI

// MARK: - Design Tokens: Spacing
// 4pt base grid

enum SelahSpacing {
    static let xs: CGFloat  = 4     // icon-to-text gap
    static let sm: CGFloat  = 8     // tight element spacing
    static let md: CGFloat  = 12    // card internal padding
    static let lg: CGFloat  = 16    // card-to-card / section spacing
    static let xl: CGFloat  = 20    // section gap
    static let xxl: CGFloat = 24    // large section gap
    static let page: CGFloat = 20   // horizontal page padding
}

// MARK: - Design Tokens: Corner Radius

enum SelahCornerRadius {
    static let xs: CGFloat  = 6     // small tags
    static let sm: CGFloat  = 10    // buttons / chips
    static let md: CGFloat  = 12    // small cards / inputs
    static let lg: CGFloat  = 16    // standard cards
    static let xl: CGFloat  = 22    // large cards / quiz card
    static let pill: CGFloat = 999  // pill shape
}

// MARK: - Design Tokens: Shadows

/// Tuple type for shadow definitions used across components.
struct SelahShadowTuple {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum SelahShadow {
    /// Small shadow - card default
    static let sm = SelahShadowTuple(
        color: Color.black.opacity(0.04),
        radius: CGFloat(2),
        x: CGFloat(0),
        y: CGFloat(1)
    )

    /// Medium shadow - hover / active
    static let md = SelahShadowTuple(
        color: Color.black.opacity(0.06),
        radius: CGFloat(8),
        x: CGFloat(0),
        y: CGFloat(4)
    )

    /// Large shadow - modal / floating
    static let lg = SelahShadowTuple(
        color: Color.black.opacity(0.08),
        radius: CGFloat(20),
        x: CGFloat(0),
        y: CGFloat(10)
    )
}

// MARK: - Animation Tokens

/// Animation duration constants (in seconds).
enum SelahAnimationDuration {
    static let quick: Double    = 0.2     // button state, chip select
    static let standard: Double = 0.35    // card hover, page element
    static let slow: Double     = 0.5     // page transition, coach hint
    static let push: Double     = 0.4     // push navigation slide
}

/// Convenience extensions for SwiftUI Animation.
extension Animation {
    /// Quick animation for button states and chip selection.
    static var selahQuick: Animation { .easeInOut(duration: SelahAnimationDuration.quick) }

    /// Standard animation for card hover and page elements.
    static var selahStandard: Animation { .easeInOut(duration: SelahAnimationDuration.standard) }

    /// Slow animation for page transitions and coach hints.
    static var selahSlow: Animation { .easeInOut(duration: SelahAnimationDuration.slow) }

    /// Spring bounce for sprite jump and celebration.
    static var selahBounce: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }
}
