import Carbon
import SwiftUI

// MARK: - 快捷键录制按钮组件
struct HotKeyRecordButton: View {
    @Binding var isRecording: Bool
    @Binding var modifiers: UInt32
    @Binding var keyCode: UInt32
    let hasConflict: Bool
    let onStartRecording: () -> Void
    let onCancelRecording: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前快捷键")
                .font(.subheadline)
                .fontWeight(.medium)

            Button(action: {
                onStartRecording()
            }) {
                HStack(spacing: 8) {
                    if isRecording {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("按下新的快捷键...")
                            .font(.system(size: 14, design: .monospaced))
                    } else {
                        Image(systemName: "keyboard")
                        Text(getHotKeyDescription())
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    isRecording ? Color.purple.opacity(0.1) : Color(NSColor.windowBackgroundColor)
                )
                .foregroundColor(isRecording ? .purple : .primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            hasConflict
                                ? Color.red
                                : (isRecording ? Color.purple : Color.secondary.opacity(0.3)),
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isRecording)

            if isRecording {
                Button("取消录制") {
                    onCancelRecording()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func getHotKeyDescription() -> String {
        var description = ""

        if modifiers & UInt32(controlKey) != 0 {
            description += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            description += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            description += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            description += "⌘"
        }

        description += ConfigManager.getKeyName(for: keyCode)

        return description
    }
}

// MARK: - 快捷键基本信息表单
struct HotKeyBasicInfoForm: View {
    @Binding var name: String
    @Binding var type: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("快捷键名称")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("为这个快捷键起一个描述性的名字", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("快捷键类型")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker(selection: $type, label: Text("快捷键类型")) {
                        Text("open").tag("open")
                        Text("web").tag("web")
                        Text("search").tag("search")
                        Text("query").tag("query")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("快捷输入文本")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - 快捷键设置卡片
struct HotKeySettingsCard: View {
    @Binding var isRecording: Bool
    @Binding var modifiers: UInt32
    @Binding var keyCode: UInt32
    let hasConflict: Bool
    let onStartRecording: () -> Void
    let onCancelRecording: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("快捷键设置")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if hasConflict {
                    Text("快捷键冲突")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            HotKeyRecordButton(
                isRecording: $isRecording,
                modifiers: $modifiers,
                keyCode: $keyCode,
                hasConflict: hasConflict,
                onStartRecording: onStartRecording,
                onCancelRecording: onCancelRecording
            )
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - 快捷键预览卡片
struct HotKeyPreviewCard: View {
    let isValid: Bool
    let modifiers: UInt32
    let keyCode: UInt32
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("预览")
                .font(.headline)
                .fontWeight(.semibold)

            if isValid {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("快捷键:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(getHotKeyDescription())
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入内容:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(text)
                            .font(.caption)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("请填写完整信息")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func getHotKeyDescription() -> String {
        var description = ""

        if modifiers & UInt32(controlKey) != 0 {
            description += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            description += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            description += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            description += "⌘"
        }

        description += ConfigManager.getKeyName(for: keyCode)

        return description
    }
}
