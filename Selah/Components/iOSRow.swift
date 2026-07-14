import SwiftUI

// MARK: - iOSRow (List Row)

/// Standard list row component used across Today and Notes.
/// [icon 40x40] [title + subtitle] [→]
struct iOSRow: View {
    let icon: String           // emoji or SF Symbol
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil
    var isDisabled: Bool = false
    var isHighlighted: Bool = false  // dashed coral border for "Today Sentence"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: SelahSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: SelahCornerRadius.sm)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(icon)
                        .font(.system(size: 20))
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .selahHeadlineMedium()

                    Text(subtitle)
                        .selahBodySmall()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Badge or chevron
                if let badge = badge {
                    Badge(text: badge, style: .coral)
                }
                Text("›")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.selahTextTertiary)
            }
            .padding(SelahSpacing.lg)
            .background(Color.selahCardPrimary)
            .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                    .strokeBorder(
                        isHighlighted ? Color.selahCoral : Color.selahBorderLight,
                        style: StrokeStyle(
                            lineWidth: isHighlighted ? 1.5 : 1,
                            dash: isHighlighted ? [6, 3] : []
                        )
                    )
            )
            .shadow(
                color: SelahShadow.sm.color,
                radius: SelahShadow.sm.radius,
                x: SelahShadow.sm.x,
                y: SelahShadow.sm.y
            )
        }
        .buttonStyle(.plain)
        .selahAccessibility(
            label: title,
            hint: isDisabled ? "目前無法使用" : "點一下開啟",
            value: badge
        )
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }
}

// MARK: - Badge

/// Pill-shaped label. Used for categories, states, and counts.
struct Badge: View {
    enum Style: String, CaseIterable {
        case coral, sage, amber, lavender

        var bg: Color {
            switch self {
            case .coral:    return .selahCoralSoft
            case .sage:     return .selahSageSoft
            case .amber:    return .selahAmberSoft
            case .lavender: return .selahLavenderSoft
            }
        }

        var text: Color {
            switch self {
            case .coral:    return .selahCoral
            case .sage:     return .selahSage
            case .amber:    return .selahAmber
            case .lavender: return .selahLavender
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .selahLabelSmall()
            .foregroundColor(style.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(style.bg)
            .clipShape(Capsule())
    }
}

// MARK: - CatChip (Category Filter Chip)

/// Horizontal scrolling category filter chip.
struct CatChip: View {
    let category: SentenceCategory
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category.emoji)
                Text(category.displayName)
                    .font(Font.selahLabelLarge)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.selahCoralSoft : Color.selahCardPrimary)
            .foregroundColor(isSelected ? .selahCoral : .selahTextSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.selahCoral : Color.selahBorderLight,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.selahQuick, value: isSelected)
    }
}
