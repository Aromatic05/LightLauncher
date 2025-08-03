import SwiftUI
import Carbon

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
            
            Text(getKeyCodeString())
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
    
    private func getKeyCodeString() -> String {
        return ConfigManager.getKeyName(for: hotKey.keyCode)
    }
}
