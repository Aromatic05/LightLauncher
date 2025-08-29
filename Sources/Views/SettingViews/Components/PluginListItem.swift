import SwiftUI

struct PluginListItem: View {
    let plugin: Plugin
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 20))
                    .foregroundColor(plugin.isEnabled ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.manifest.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(plugin.command)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { plugin.isEnabled },
                        set: { onToggle($0) }
                    )
                )
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}
