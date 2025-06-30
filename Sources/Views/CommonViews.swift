import SwiftUI
import AppKit

// MARK: - Common Views
struct CommandSuggestionsView: View {
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
                    CommandSuggestionRow(command: command)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommandSuggestionRow: View {
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
