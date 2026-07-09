import SwiftUI

// MARK: - PetView (Sprite Display)

/// The gentle language sprite companion.
/// Shows the seed character with decoration stages, mood, name,
/// and today's story.
struct PetView: View {
    let companion: Companion
    var todayStory: String = ""

    @State private var floatOffset: CGFloat = 0
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: SelahSpacing.sm) {
            // Sprite body
            ZStack {
                // Float animation
                spriteBody
                    .offset(y: floatOffset)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: floatOffset
                    )

                // Decoration (sprout / leaf / bud / bloom)
                decorationView
                    .offset(y: -38)
            }
            .frame(width: 100, height: 120)
            .onAppear {
                floatOffset = -6
            }

            // Name
            Text(companion.displayName)
                .selahHeadlineMedium()

            // Mood text
            moodText
                .selahBodySmall()

            // Today's story card
            if !todayStory.isEmpty {
                storyCard
            }
        }
    }

    // MARK: - Sprite Body

    private var spriteBody: some View {
        ZStack {
            // Body: amber gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.selahAmber, Color.selahAmber.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)

            // Eyes: two black dots
            HStack(spacing: 16) {
                Circle().fill(Color.selahTextPrimary).frame(width: 6, height: 6)
                Circle().fill(Color.selahTextPrimary).frame(width: 6, height: 6)
            }

            // Smile: arc
            SmileArc()
                .stroke(Color.selahTextPrimary, lineWidth: 2)
                .frame(width: 20, height: 10)
                .offset(y: 6)

            // Blush: two coral circles
            HStack(spacing: 36) {
                Circle().fill(Color.selahCoral.opacity(0.15)).frame(width: 8, height: 6)
                Circle().fill(Color.selahCoral.opacity(0.15)).frame(width: 8, height: 6)
            }
            .offset(y: 10)
        }
    }

    // MARK: - Decoration

    @ViewBuilder
    private var decorationView: some View {
        switch companion.decorationStage {
        case .none:
            EmptyView()
        case .sprout:
            // Small leaf sprout
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(.selahSage)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(), value: isAnimating)
                .onAppear { isAnimating = true }
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

    // MARK: - Mood Text

    private var moodText: some View {
        switch companion.mood {
        case .happy:
            return Text("今天很有精神 ✨")
                .foregroundColor(.selahSage)
        case .neutral:
            return Text("靜靜地陪著你 🌱")
                .foregroundColor(.selahTextSecondary)
        case .quiet:
            return Text("好久不見了呢")
                .foregroundColor(.selahTextTertiary)
        }
    }

    // MARK: - Story Card

    private var storyCard: some View {
        Text(todayStory)
            .font(.selahBodyMedium)
            .foregroundColor(.selahTextSecondary)
            .multilineTextAlignment(.center)
            .padding(SelahSpacing.md)
            .frame(maxWidth: 280)
            .background(Color.selahCardPrimary)
            .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
            .shadow(
                color: SelahShadow.sm.color,
                radius: SelahShadow.sm.radius,
                x: SelahShadow.sm.x,
                y: SelahShadow.sm.y
            )
    }
}

// MARK: - Smile Arc Shape

private struct SmileArc: Shape {
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

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        PetView(
            companion: Companion(
                displayName: "小豆",
                active: true
            ),
            todayStory: "小豆今天學到了 swamped，下次忙翻的時候可以用！"
        )
    }
    .padding()
    .background(Color.selahBgPrimary)
}
