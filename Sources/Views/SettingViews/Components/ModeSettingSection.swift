import SwiftUI

struct ModeSettingSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    @Binding var isEnabled: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _ in
                        onToggle()
                    }
                    .scaleEffect(1.2)
            }
            if isEnabled {
                content
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isEnabled
                        ? iconColor.opacity(0.05)
                        : Color(NSColor.controlBackgroundColor).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEnabled ? iconColor.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
