import SwiftUI
import AppKit

// MARK: - 增强命令建议视图
struct CommandSuggestionsView: View {
    let commands: [LauncherCommand]
    @Binding var selectedIndex: Int
    let onCommandSelected: (LauncherCommand) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.blue)
                Text("可用命令")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !commands.isEmpty {
                    Text("Space 选择 • ↑↓ 导航")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            if commands.isEmpty {
                Text("没有匹配的命令")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(commands.enumerated()), id: \.element.trigger) { index, command in
                        SelectableCommandSuggestionRow(
                            command: command,
                            isSelected: index == selectedIndex,
                            onTap: {
                                onCommandSelected(command)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SelectableCommandSuggestionRow: View {
    let command: LauncherCommand
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: command.mode.iconName)
                .foregroundColor(command.mode == .kill ? .red : .blue)
                .frame(width: 20, height: 20)
            
            // 命令信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(command.trigger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(command.mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .primary)
                }
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            // 状态指示器
            if command.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 旧版命令建议视图（保持兼容性）
struct LegacyCommandSuggestionsView: View {
    let commands: [LauncherCommand]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.blue)
                Text("可用命令")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            VStack(spacing: 8) {
                ForEach(commands, id: \.trigger) { command in
                    LegacyCommandSuggestionRow(command: command)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LegacyCommandSuggestionRow: View {
    let command: LauncherCommand
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: command.mode.iconName)
                .foregroundColor(command.mode == .kill ? .red : .blue)
                .frame(width: 20, height: 20)
            
            // 命令信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(command.trigger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Text(command.mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态指示器
            if command.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
    }
}
