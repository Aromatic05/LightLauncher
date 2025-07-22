import SwiftUI
import Carbon

// MARK: - 选项卡按钮
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 设置行组件
struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isToggle: Bool
    @Binding var toggleValue: Bool
    let action: () -> Void
    
    init(icon: String, iconColor: Color = .accentColor, title: String, description: String, 
         isToggle: Bool = false, toggleValue: Binding<Bool> = .constant(false), action: @escaping () -> Void = {}) {
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
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // 文本内容
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 控件
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

// MARK: - 快捷键信息卡片
struct HotKeyInfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iconColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - 功能项组件
struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title3)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - 目录行组件
struct DirectoryRow: View {
    let directory: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(directory)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("删除") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - 缩写行组件
struct AbbreviationRow: View {
    let key: String
    let values: [String]
    let isEditing: Bool
    @Binding var editingValues: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩写键
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // 匹配值
            if isEditing {
                TextField("编辑匹配词", text: $editingValues)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 8) {
                    Button("保存") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("取消") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text(values.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Button("编辑") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("删除") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - 模式设置区块组件
struct ModeSettingSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    @Binding var isEnabled: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题和开关
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _ in
                        onToggle()
                    }
                    .scaleEffect(1.2)
            }
            
            // 详细内容（仅在启用时显示）
            if isEnabled {
                content
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEnabled ? iconColor.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled ? iconColor.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 配置文件内容查看器
struct ConfigContentView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("配置文件内容")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(24)
        .frame(width: 700, height: 600)
    }
}
