import SwiftUI

// MARK: - CoachHint

/// Learning coach hint. Shown first 3-5 times per feature, then auto-hidden.
struct CoachHint: View {
    let text: String
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: SelahSpacing.sm) {
                Text("💡")
                Text(text)
                    .selahBodySmall()
                    .foregroundColor(.selahSage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { dismiss() }) {
                    Text("知道了")
                        .font(.selahLabelSmall)
                        .foregroundColor(.selahSage)
                        .underline()
                }
            }
            .padding(10)
            .padding(.horizontal, 4)
            .background(Color.selahSageSoft)
            .overlay(
                RoundedRectangle(cornerRadius: SelahCornerRadius.md)
                    .strokeBorder(Color.selahSage.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.selahSlow, value: isVisible)
        }
    }

    private func dismiss() {
        withAnimation(.selahSlow) {
            isVisible = false
        }
    }
}

// MARK: - ProgressBar

/// Simple progress bar showing fill percentage.
struct ProgressBar: View {
    let progress: Double  // 0.0 ... 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.selahBorderLight)
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.selahSage)
                    .frame(width: geometry.size.width * progress, height: 5)
                    .animation(.selahStandard, value: progress)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - StageBar

/// 4-step progress indicator for the Listen flow.
struct StageBar: View {
    let currentStage: Int  // 1-4
    let maxStage: Int      // highest unlocked stage

    var body: some View {
        VStack(spacing: SelahSpacing.xs) {
            // Progress tabs
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { stage in
                    RoundedRectangle(cornerRadius: 2)
                        .frame(height: 4)
                        .foregroundColor(stageColor(for: stage))
                }
            }

            // Stage labels
            HStack(spacing: 4) {
                stageLabel("🎧 聽", stage: 1)
                stageLabel("🧠 猜", stage: 2)
                stageLabel("🔍 拆", stage: 3)
                stageLabel("🗣️ 說", stage: 4)
            }
        }
    }

    private func stageColor(for stage: Int) -> Color {
        if stage < currentStage { return .selahLavender }
        if stage == currentStage { return .selahLavender }
        if stage <= maxStage { return .selahBorderLight }
        return .selahBorderLight
    }

    private func stageLabel(_ text: String, stage: Int) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.selahLabelSmall)
                .foregroundColor(
                    stage <= currentStage ? .selahLavender : .selahTextTertiary
                )
            if stage > maxStage {
                Text("🔒")
                    .font(.system(size: 8))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

/// Auto-dismissing notification toast.
struct ToastView: View {
    let message: String
    let style: ToastStyle

    enum ToastStyle {
        case success
        case info

        var bg: Color {
            switch self {
            case .success: return .selahSage
            case .info:    return .selahLavender
            }
        }
    }

    var body: some View {
        Text(message)
            .font(.selahBodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(style.bg)
            .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
            .shadow(
                color: SelahShadow.md.color,
                radius: SelahShadow.md.radius,
                x: SelahShadow.md.x,
                y: SelahShadow.md.y
            )
    }
}
