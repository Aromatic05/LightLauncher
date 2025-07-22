import SwiftUI
import Carbon

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    @Binding var isRecordingHotKey: Bool
    @Binding var tempHotKeyDescription: String
    @Binding var globalMonitor: Any?
    @Binding var localMonitor: Any?
    @Binding var currentModifiers: UInt32
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用设置")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("基础应用配置和快捷键设置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 设置组
                VStack(spacing: 32) {
                    // 开机自启动
                    SettingRow(
                        icon: "power",
                        iconColor: .green,
                        title: "开机自启动",
                        description: "启动时自动运行 LightLauncher",
                        isToggle: true,
                        toggleValue: $settingsManager.isAutoStartEnabled
                    ) {
                        settingsManager.toggleAutoStart()
                    }
                    
                    Divider()
                    
                    // 快捷键设置
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundColor(.blue)
                            Text("全局快捷键")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("设置全局快捷键来显示/隐藏启动器，在任何应用中都可以使用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("当前快捷键")
                                    .font(.headline)
                                Text("点击按钮来修改")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                startRecordingHotKey()
                            }) {
                                HStack(spacing: 8) {
                                    if isRecordingHotKey {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("按下新的快捷键...")
                                            .font(.system(size: 14, design: .monospaced))
                                    } else {
                                        Image(systemName: "keyboard")
                                        Text(configManager.getHotKeyDescription())
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(isRecordingHotKey ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(isRecordingHotKey ? .blue : .primary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isRecordingHotKey ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isRecordingHotKey)
                            
                            if isRecordingHotKey {
                                Button("取消") {
                                    cancelRecordingHotKey()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("重置") {
                                    resetToDefaults()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.orange)
                            }
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // 快捷键说明 - 横向布局
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("支持的快捷键类型")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // 横向排列的快捷键类型
                        HStack(alignment: .top, spacing: 20) {
                            HotKeyInfoCard(
                                title: "修饰键组合",
                                icon: "command",
                                iconColor: .blue,
                                examples: ["⌘ + 字母", "⌥ + 数字", "⌃ + 功能键", "多键组合"]
                            )
                            
                            HotKeyInfoCard(
                                title: "单独修饰键",
                                icon: "option",
                                iconColor: .purple,
                                examples: ["右 Command", "右 Option", "左/右 Control", "Shift 键"]
                            )
                            
                            HotKeyInfoCard(
                                title: "功能键",
                                icon: "f.cursive",
                                iconColor: .orange,
                                examples: ["F1 - F12", "Space", "Return", "Escape"]
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
    
    // MARK: - 热键录制方法
    private func startRecordingHotKey() {
        isRecordingHotKey = true
        tempHotKeyDescription = "按下新的快捷键..."
        currentModifiers = 0
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
            return event
        }
    }
    
    private func handleHotKeyEvent(_ event: NSEvent) {
        guard isRecordingHotKey else { return }
        
        if event.type == .keyDown {
            let keyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags
            
            let validKeys: [UInt32] = [
                UInt32(kVK_Space), UInt32(kVK_Return), UInt32(kVK_Escape), UInt32(kVK_Tab),
                UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
                UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
                UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
                UInt32(kVK_ANSI_A), UInt32(kVK_ANSI_B), UInt32(kVK_ANSI_C), UInt32(kVK_ANSI_D),
                UInt32(kVK_ANSI_E), UInt32(kVK_ANSI_F), UInt32(kVK_ANSI_G), UInt32(kVK_ANSI_H),
                UInt32(kVK_ANSI_I), UInt32(kVK_ANSI_J), UInt32(kVK_ANSI_K), UInt32(kVK_ANSI_L),
                UInt32(kVK_ANSI_M), UInt32(kVK_ANSI_N), UInt32(kVK_ANSI_O), UInt32(kVK_ANSI_P),
                UInt32(kVK_ANSI_Q), UInt32(kVK_ANSI_R), UInt32(kVK_ANSI_S), UInt32(kVK_ANSI_T),
                UInt32(kVK_ANSI_U), UInt32(kVK_ANSI_V), UInt32(kVK_ANSI_W), UInt32(kVK_ANSI_X),
                UInt32(kVK_ANSI_Y), UInt32(kVK_ANSI_Z)
            ]
            
            if validKeys.contains(keyCode) || (modifiers.rawValue != 0) {
                let carbonModifiers = carbonModifiersFromCocoaModifiers(modifiers)
                configManager.updateHotKey(modifiers: carbonModifiers, keyCode: keyCode)
                stopRecordingHotKey()
            }
        } else if event.type == .flagsChanged {
            // 处理单独修饰键
            let modifiers = event.modifierFlags
            currentModifiers = carbonModifiersFromCocoaModifiers(modifiers)
            
            // 检查是否为单独的右 Command 或右 Option
            if modifiers.contains(.command) && event.keyCode == 54 { // 右 Command
                configManager.updateHotKey(modifiers: 0x100010, keyCode: 0)
                stopRecordingHotKey()
            } else if modifiers.contains(.option) && event.keyCode == 61 { // 右 Option
                configManager.updateHotKey(modifiers: 0x100040, keyCode: 0)
                stopRecordingHotKey()
            }
        }
    }
    
    private func carbonModifiersFromCocoaModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        
        return carbonModifiers
    }
    
    private func stopRecordingHotKey() {
        isRecordingHotKey = false
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func cancelRecordingHotKey() {
        stopRecordingHotKey()
    }
    
    private func resetToDefaults() {
        configManager.updateHotKey(modifiers: UInt32(optionKey), keyCode: UInt32(kVK_Space))
    }
}
