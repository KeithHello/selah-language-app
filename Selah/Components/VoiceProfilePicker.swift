import SwiftUI

/// Reusable voice profile picker component.
/// Shows as a pill-shaped dropdown that expands to show all voice options.
/// Used in TodaySentenceView (per-sentence selection) and Settings (default voice).
struct VoiceProfilePicker: View {
    @Binding var selected: VoiceProfile
    var allowAdvanced: Bool = true

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact pill
            Button(action: {
                withAnimation(.selahStandard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                    Text(selected.displayName)
                        .font(.selahLabelLarge)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(.selahCoral)
                .padding(.horizontal, SelahSpacing.md)
                .padding(.vertical, SelahSpacing.sm)
                .background(Color.selahCoralSoft)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Expanded options
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(VoiceProfile.allCases, id: \.self) { voice in
                        if allowAdvanced || voice.isDefault {
                            voiceRow(voice)
                        }
                    }
                }
                .padding(SelahSpacing.sm)
                .background(Color.selahCardPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: SelahCornerRadius.md)
                        .strokeBorder(Color.selahBorderLight, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.top, SelahSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.selahStandard, value: isExpanded)
    }

    private func voiceRow(_ voice: VoiceProfile) -> some View {
        Button(action: {
            selected = voice
            withAnimation(.selahStandard) {
                isExpanded = false
            }
        }) {
            HStack(spacing: SelahSpacing.sm) {
                // Selected indicator
                Image(systemName: selected == voice ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(selected == voice ? .selahCoral : .selahBorder)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(voice.displayName)
                            .font(.selahBodyMedium)
                            .foregroundColor(.selahTextPrimary)
                        if !voice.isDefault {
                            Text("進階")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.selahLavender)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.selahLavenderSoft)
                                .clipShape(Capsule())
                        }
                    }
                    Text(voice.description)
                        .font(.selahBodySmall)
                        .foregroundColor(.selahTextTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, SelahSpacing.sm)
            .padding(.vertical, SelahSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
