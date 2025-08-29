import SwiftUI

struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isToggle: Bool
    @Binding var toggleValue: Bool
    let action: () -> Void

    init(
        icon: String, iconColor: Color = .accentColor, title: String, description: String,
        isToggle: Bool = false, toggleValue: Binding<Bool> = .constant(false),
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.isToggle = isToggle
        self._toggleValue = toggleValue
        self.action = action
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isToggle {
                Toggle("", isOn: $toggleValue)
                    .onChange(of: toggleValue) { _ in
                        action()
                    }
                    .scaleEffect(1.1)
            }
        }
        .padding(.vertical, 8)
    }
}
