import AppKit
import SwiftUI

struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    let index: Int
    let mode: LauncherMode

    var body: some View {
        NumberedIconRow(
            index: index,
            icon: app.icon,
            fallbackIconName: "app",
            fallbackGradient: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
            title: app.name,
            subtitle: "Application",
            subtitleColor: .secondary,
            isSelected: isSelected,
            selectedGradient: [Color.accentColor, Color.accentColor.opacity(0.8)]
        ) {
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct PreferencePaneRowView: View {
    let pane: PreferencePaneItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        NumberedIconRow(
            index: index,
            icon: pane.icon,
            fallbackIconName: "gearshape",
            fallbackGradient: [Color.blue.opacity(0.3), Color.blue.opacity(0.2)],
            title: pane.title,
            subtitle: "System Setting",
            subtitleColor: .secondary,
            isSelected: isSelected,
            selectedGradient: [Color.blue, Color.blue.opacity(0.8)]
        ) {
            if isSelected {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct SystemCommandRowView: View {
    let command: SystemCommandItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        NumberedIconRow(
            index: index,
            icon: command.icon,
            fallbackIconName: "command",
            fallbackGradient: [Color.purple.opacity(0.3), Color.purple.opacity(0.2)],
            title: command.displayName,
            subtitle: command.subtitle,
            subtitleColor: .secondary,
            isSelected: isSelected,
            selectedGradient: [Color.purple, Color.purple.opacity(0.8)]
        ) {
            if isSelected {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
