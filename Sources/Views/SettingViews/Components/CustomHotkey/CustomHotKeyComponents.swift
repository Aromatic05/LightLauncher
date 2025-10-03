import SwiftUI

// MARK: - 自定义快捷键行视图
struct CustomHotKeyRow: View {
    let hotKey: CustomHotKeyConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：简要说明
            VStack(alignment: .leading, spacing: 6) {
                Text(hotKey.name)
                    .font(.headline)
                Text(hotKey.text.count > 40 ? String(hotKey.text.prefix(40)) + "..." : hotKey.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            // 中间：快捷键显示按钮（和 GeneralSettingsView 同款，可点击编辑）
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                    Text(HotKeyUtils.getHotKeyDescription(
                        modifiers: hotKey.modifiers,
                        keyCode: hotKey.keyCode
                    ))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 右侧：小号删除编辑图标
            // 编辑按钮（小号）
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .help("编辑此快捷键")

            // 删除按钮（小号）
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .help("删除此快捷键")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

