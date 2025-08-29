import AppKit
import SwiftUI

// MARK: - 应用行视图
struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    let index: Int
    let mode: LauncherMode

    var body: some View {
        HStack(spacing: 16) {
            // Number label
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 24, height: 24)

                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }

            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text("Application")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 设置项行视图
struct PreferencePaneRowView: View {
    let pane: PreferencePaneItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            // Number label
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 24, height: 24)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            // 设置图标
            if let icon = pane.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }

            // 设置名称
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                Text("System Setting")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 系统命令行视图
struct SystemCommandRowView: View {
    let command: SystemCommandItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            // Number label
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 24, height: 24)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            // Command icon
            if let icon = command.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "command")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }

            // Command name & subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(command.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
