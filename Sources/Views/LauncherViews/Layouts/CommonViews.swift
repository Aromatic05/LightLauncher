import SwiftUI
import AppKit

// MARK: - 增强命令建议视图
struct CommandSuggestionsView: View {
    // 【修改】接收的数据类型从 [LauncherCommand] 变为 [CommandRecord]
    let commands: [CommandRecord]
    @Binding var selectedIndex: Int
    // 【修改】回调的参数类型变为 CommandRecord
    let onCommandSelected: (CommandRecord) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
            .padding(.top, 0)
            
            if commands.isEmpty {
                Text("没有匹配的命令")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            // 【修改】ID 现在使用 CommandRecord 的 `prefix` 属性，它保证唯一
                            ForEach(Array(commands.enumerated()), id: \.element.prefix) { index, command in
                                SelectableCommandSuggestionRow(
                                    // 【修改】传递 CommandRecord 给子视图
                                    command: command,
                                    isSelected: index == selectedIndex,
                                    onTap: {
                                        onCommandSelected(command)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 0)
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SelectableCommandSuggestionRow: View {
    // 【修改】接收的数据类型从 LauncherCommand 变为 CommandRecord
    let command: CommandRecord
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            // 【修改】直接从 CommandRecord 获取 iconName
            Image(systemName: command.iconName)
                .foregroundColor(command.mode == .kill ? .red : .blue)
                .frame(width: 20, height: 20)
            
            // 命令信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 【修改】直接从 CommandRecord 获取 prefix
                    Text(command.prefix)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    // 【修改】直接从 CommandRecord 获取 displayName
                    Text(command.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .primary)
                }
                
                // 【修改】直接从 CommandRecord 获取 description
                Text(command.description ?? "")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            // 状态指示器
            // 注意：CommandRegistry 在注册时已经确保了只有启用的命令才会被添加，
            // 所以理论上这里不再需要 isEnabled 的判断，但为了 UI 兼容性暂时保留。
            // 如果您确认所有注册的命令都是启用的，可以移除这个 Image。
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
                .font(.caption)
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