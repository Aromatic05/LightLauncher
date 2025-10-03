import SwiftUI

// MARK: - 快捷键卡片组件
/// 通用的快捷键显示和修改组件，支持录制和编辑快捷键
struct HotKeyCard: View {
    // MARK: - Properties
    let title: String
    let description: String?
    let icon: String
    let iconColor: Color
    
    @ObservedObject var recorder: HotKeyRecorder
    @Binding var modifiers: UInt32
    @Binding var keyCode: UInt32
    
    let hasConflict: Bool
    let showResetButton: Bool
    
    let onKeyRecorded: (UInt32, UInt32) -> Void
    let onReset: (() -> Void)?
    
    // MARK: - Initialization
    init(
        title: String,
        description: String? = nil,
        icon: String = "keyboard",
        iconColor: Color = .blue,
        recorder: HotKeyRecorder,
        modifiers: Binding<UInt32>,
        keyCode: Binding<UInt32>,
        hasConflict: Bool = false,
        showResetButton: Bool = true,
        onKeyRecorded: @escaping (UInt32, UInt32) -> Void,
        onReset: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.recorder = recorder
        self._modifiers = modifiers
        self._keyCode = keyCode
        self.hasConflict = hasConflict
        self.showResetButton = showResetButton
        self.onKeyRecorded = onKeyRecorded
        self.onReset = onReset
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题和冲突提示
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if hasConflict {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("快捷键冲突")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // 描述文本
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 快捷键设置区域
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前快捷键")
                        .font(.headline)
                    Text(recorder.isRecording ? "按下新的快捷键..." : "点击按钮来修改")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 快捷键录制按钮
                Button(action: {
                    if !recorder.isRecording {
                        recorder.onKeyRecorded = onKeyRecorded
                        recorder.startRecording()
                    }
                }) {
                    HStack(spacing: 8) {
                        if recorder.isRecording {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("按下新的快捷键...")
                                .font(.system(size: 14, design: .monospaced))
                        } else {
                            Image(systemName: "keyboard")
                            Text(HotKeyUtils.getHotKeyDescription(
                                modifiers: modifiers,
                                keyCode: keyCode
                            ))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        recorder.isRecording
                            ? iconColor.opacity(0.1)
                            : Color(NSColor.controlBackgroundColor)
                    )
                    .foregroundColor(recorder.isRecording ? iconColor : .primary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                hasConflict
                                    ? Color.red
                                    : (recorder.isRecording ? iconColor : Color.secondary.opacity(0.3)),
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(recorder.isRecording)
                
                // 取消/重置按钮
                if recorder.isRecording {
                    Button("取消") {
                        recorder.cancelRecording()
                    }
                    .buttonStyle(.bordered)
                } else if showResetButton, let onReset = onReset {
                    Button("重置") {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
        }
        .onDisappear {
            recorder.stopRecording()
        }
    }
}

// MARK: - 简化版快捷键卡片（用于列表展示）
struct CompactHotKeyCard: View {
    let title: String
    let modifiers: UInt32
    let keyCode: UInt32
    let hasConflict: Bool
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    
    init(
        title: String,
        modifiers: UInt32,
        keyCode: UInt32,
        hasConflict: Bool = false,
        onEdit: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.hasConflict = hasConflict
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 快捷键显示
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(HotKeyUtils.getHotKeyDescription(
                    modifiers: modifiers,
                    keyCode: keyCode
                ))
                .font(.system(.subheadline, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            
            Spacer()
            
            // 冲突提示
            if hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("编辑快捷键")
                
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("删除快捷键")
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(hasConflict ? Color.red : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 快捷键预览组件
struct HotKeyPreview: View {
    let modifiers: UInt32
    let keyCode: UInt32
    let text: String?
    let isValid: Bool
    
    init(
        modifiers: UInt32,
        keyCode: UInt32,
        text: String? = nil,
        isValid: Bool = true
    ) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.text = text
        self.isValid = isValid
    }
    
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
                        Text(HotKeyUtils.getHotKeyDescription(
                            modifiers: modifiers,
                            keyCode: keyCode
                        ))
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                    
                    if let text = text, !text.isEmpty {
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
}
