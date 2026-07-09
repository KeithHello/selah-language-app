import SwiftUI

// MARK: - QuizCard (Flip Card)

struct QuizCard: View {
    let zhText: String
    let enText: String

    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: SelahSpacing.lg) {
            // Category badge
            Badge(text: "練習", style: .lavender)

            // Chinese text (always visible)
            Text(zhText)
                .font(.selahDisplayMedium)
                .foregroundColor(.selahTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, SelahSpacing.md)

            // Reveal area
            VStack(spacing: SelahSpacing.md) {
                if isRevealed {
                    Text(enText)
                        .font(.selahHeadlineLarge)
                        .foregroundColor(.selahSage)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button(action: { reveal() }) {
                        HStack {
                            Text("點擊揭示答案")
                                .selahBodyLarge()
                            Image(systemName: "eyes")
                        }
                        .foregroundColor(.selahTextTertiary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: SelahCornerRadius.sm)
                                .strokeBorder(
                                    Color.selahBorder,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(SelahSpacing.xl)
        .background(Color.selahCardPrimary)
        .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.xl))
        .shadow(
            color: SelahShadow.md.color,
            radius: SelahShadow.md.radius,
            x: SelahShadow.md.x,
            y: SelahShadow.md.y
        )
        .animation(.selahStandard, value: isRevealed)
    }

    func reveal() {
        withAnimation(.selahStandard) {
            isRevealed = true
        }
        // Haptic: light impact on flip
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Assessment Buttons

struct AssessmentButtons: View {
    var onGood: () -> Void = {}
    var onMid: () -> Void = {}
    var onFail: () -> Void = {}

    var body: some View {
        HStack(spacing: SelahSpacing.sm) {
            // Good
            Button(action: onGood) {
                Text("記得很清楚 ✅")
                    .font(.selahLabelLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(Color.selahSage)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }

            // Almost
            Button(action: onMid) {
                Text("差一點 🤔")
                    .font(.selahLabelLarge)
                    .foregroundColor(.selahAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(Color.selahAmberSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: SelahCornerRadius.sm)
                            .strokeBorder(Color.selahAmber, lineWidth: 1)
                    )
            }

            // Fail
            Button(action: onFail) {
                Text("完全不會 😵")
                    .font(.selahLabelLarge)
                    .foregroundColor(.selahTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(Color.selahBgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: SelahCornerRadius.sm)
                            .strokeBorder(Color.selahBorder, lineWidth: 1)
                    )
            }
        }
    }
}
