import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var isRecordingHotKey = false
    @State private var tempHotKeyDescription = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题
            HStack {
                Text("LightLauncher 设置")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 24)
            
            // 设置内容
            VStack(alignment: .leading, spacing: 20) {
                // 开机自启动
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("开机自启动")
                            .font(.headline)
                        Text("启动时自动运行 LightLauncher")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settingsManager.isAutoStartEnabled)
                        .onChange(of: settingsManager.isAutoStartEnabled) { _ in
                            settingsManager.toggleAutoStart()
                        }
                        .scaleEffect(1.1)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // 快捷键设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("全局快捷键")
                        .font(.headline)
                    Text("用于显示/隐藏启动器的快捷键")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("当前快捷键:")
                            .font(.body)
                        
                        Button(action: {
                            startRecordingHotKey()
                        }) {
                            Text(isRecordingHotKey ? "按下新的快捷键..." : settingsManager.getHotKeyDescription())
                                .font(.system(size: 16, design: .monospaced))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isRecordingHotKey ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isRecordingHotKey ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if isRecordingHotKey {
                            Button("取消") {
                                cancelRecordingHotKey()
                            }
                            .font(.body)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // 关于部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("版本:")
                                .font(.body)
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        
                        HStack {
                            Text("构建:")
                                .font(.body)
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        
                        HStack {
                            Text("描述:")
                                .font(.body)
                            Text("快速、智能的应用启动器")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // 底部按钮
                HStack {
                    Button("重置为默认") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                    .font(.body)
                    
                    Spacer()
                    
                    Button("退出应用") {
                        NSApplication.shared.terminate(nil)
                    }
                    .foregroundColor(.red)
                    .font(.body)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 900, height: 720)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            settingsManager.checkAutoStartStatus()
        }
    }
    
    // MARK: - 热键录制
    
    private func startRecordingHotKey() {
        isRecordingHotKey = true
        tempHotKeyDescription = "按下新的快捷键..."
        
        // 设置全局事件监听
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleHotKeyEvent(event)
            return event
        }
    }
    
    private func handleHotKeyEvent(_ event: NSEvent) {
        guard isRecordingHotKey else { return }
        
        if event.type == .keyDown {
            let keyCode = UInt32(event.keyCode)
            let modifiers = UInt32(event.modifierFlags.rawValue)
            
            // 过滤掉一些不适合的按键
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
            
            if validKeys.contains(keyCode) {
                // 确保有修饰键
                let cleanModifiers = modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey))
                if cleanModifiers != 0 {
                    finishRecordingHotKey(modifiers: cleanModifiers, keyCode: keyCode)
                }
            }
        }
    }
    
    private func finishRecordingHotKey(modifiers: UInt32, keyCode: UInt32) {
        isRecordingHotKey = false
        settingsManager.updateHotKey(modifiers: modifiers, keyCode: keyCode)
        
        // 移除事件监听
        NSEvent.removeMonitor(self)
    }
    
    private func cancelRecordingHotKey() {
        isRecordingHotKey = false
        
        // 移除事件监听
        NSEvent.removeMonitor(self)
    }
    
    private func resetToDefaults() {
        settingsManager.updateHotKey(modifiers: UInt32(optionKey), keyCode: UInt32(kVK_Space))
    }
}
