import SwiftUI

// MARK: - PetView (Sprite Display)

/// The gentle language sprite companion.
/// Shows the seed character with decoration stages, mood, name,
/// and today's story.
struct PetView: View {
    let companion: Companion
    var todayStory: String = ""

    @StateObject private var animationController: PetAnimationController

    init(
        companion: Companion,
        todayStory: String = "",
        animationController: PetAnimationController? = nil
    ) {
        self.companion = companion
        self.todayStory = todayStory
        _animationController = StateObject(
            wrappedValue: animationController ?? PetAnimationController()
        )
    }

    var body: some View {
        VStack(spacing: SelahSpacing.sm) {
            // Sprite body
            ZStack {
                PetSpriteView(
                    animationController: animationController,
                    decorationStage: companion.decorationStage
                )
            }
            .selahAccessibility(label: "陪伴精靈 \(companion.displayName)", value: moodAccessibilityValue)
            .onAppear {
                animationController.setContext(.idle)
            }
            .task(id: companion.decorationStage) {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    guard !Task.isCancelled else { break }
                    animationController.trigger(.blink)

                    if companion.decorationStage != .none {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard !Task.isCancelled else { break }
                        animationController.trigger(.leafSway)
                    }
                }
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

    // MARK: - Mood Text

    private var moodAccessibilityValue: String {
        switch companion.mood {
        case .happy: return "今天很有精神"
        case .neutral: return "靜靜陪伴"
        case .quiet: return "安靜等待"
        }
    }

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
