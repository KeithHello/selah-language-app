import Foundation

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

import SwiftUI

enum SelahShadow {
    /// Small shadow — card default
    static let sm = (
        color: Color.black.opacity(0.04),
        radius: CGFloat(2),
        x: CGFloat(0),
        y: CGFloat(1)
    )

    /// Medium shadow — hover / active
    static let md = (
        color: Color.black.opacity(0.06),
        radius: CGFloat(8),
        x: CGFloat(0),
        y: CGFloat(4)
    )

    /// Large shadow — modal / floating
    static let lg = (
        color: Color.black.opacity(0.08),
        radius: CGFloat(20),
        x: CGFloat(0),
        y: CGFloat(10)
    )
}

// MARK: - Animation Tokens

enum SelahAnimation {
    static let quick: Double    = 0.2     // button state, chip select
    static let standard: Double = 0.35    // card hover, page element
    static let slow: Double     = 0.5     // page transition, coach hint
    static let push: Double     = 0.4     // push navigation slide

    /// Standard ease-out for entrance animations.
    static let easeOut = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.32, y: 0.72),
        endControlPoint: UnitPoint(x: 0, y: 1)
    )

    /// Spring for bounce animations (sprite jump, celebration).
    static let bounce: Animation = .spring(
        response: 0.5,
        dampingFraction: 0.6,
        blendDuration: 0
    )
}
