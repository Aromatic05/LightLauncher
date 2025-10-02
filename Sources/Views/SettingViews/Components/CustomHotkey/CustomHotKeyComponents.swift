import SwiftUI
import Carbon

// MARK: - 自定义快捷键空状态视图
struct CustomHotKeyEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "command.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("暂无自定义快捷键")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击\"添加快捷键\"按钮创建您的第一个自定义快捷键")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 自定义快捷键列表头部
struct CustomHotKeyListHeader: View {
    let onAddAction: () -> Void

    var body: some View {
        HStack {
            Text("快捷键配置")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onAddAction) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("添加快捷键")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - 自定义快捷键行视图
struct CustomHotKeyRow: View {
    let hotKey: CustomHotKeyConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            hotKeyDisplay
            contentView
            actionButtons
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var hotKeyDisplay: some View {
        HStack(spacing: 4) {
            ForEach(getModifierStrings(), id: \.self) { modifier in
                Text(modifier)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            Text(HotKeyUtils.getKeyName(for: hotKey.keyCode))
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(4)
        }
        .frame(width: 120, alignment: .leading)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hotKey.name)
                .font(.headline)

            Text(hotKey.text.count > 50 ? String(hotKey.text.prefix(50)) + "..." : hotKey.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func getModifierStrings() -> [String] {
        var modifiers: [String] = []

        if hotKey.modifiers & UInt32(controlKey) != 0 {
            modifiers.append("⌃")
        }
        if hotKey.modifiers & UInt32(optionKey) != 0 {
            modifiers.append("⌥")
        }
        if hotKey.modifiers & UInt32(shiftKey) != 0 {
            modifiers.append("⇧")
        }
        if hotKey.modifiers & UInt32(cmdKey) != 0 {
            modifiers.append("⌘")
        }

        return modifiers
    }
}

