import SwiftUI
import Carbon

// MARK: - 快捷键录制管理器
/// 负责处理快捷键的录制逻辑，包括事件监听、修饰键转换等
class HotKeyRecorder: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var currentModifiers: UInt32 = 0
    
    // MARK: - Private Properties
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // MARK: - Callbacks
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?
    var onRecordingCancelled: (() -> Void)?
    
    // MARK: - Public Methods
    
    /// 开始录制快捷键
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        currentModifiers = 0
        
        // 添加全局事件监听器
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // 添加本地事件监听器
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil  // 阻止事件继续传播
        }
    }
    
    /// 取消录制
    func cancelRecording() {
        stopRecording()
        onRecordingCancelled?()
    }
    
    /// 停止录制（清理监听器）
    func stopRecording() {
        isRecording = false
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// 处理键盘事件
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }
        
        if event.type == .keyDown {
            handleKeyDown(event)
        } else if event.type == .flagsChanged {
            handleFlagsChanged(event)
        }
    }
    
    /// 处理按键事件
    private func handleKeyDown(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = event.modifierFlags
        let carbonModifiers = carbonModifiersFromCocoaModifiers(modifiers)
        
        // 必须是有效按键，并且至少有一个修饰键
        // 注意：对于功能键（F1-F12），可以不需要修饰键
        let isFunctionKey = keyCode >= UInt32(kVK_F1) && keyCode <= UInt32(kVK_F12)
        let hasModifiers = carbonModifiers != 0
        
        if isValidKey(keyCode) && (hasModifiers || isFunctionKey) {
            recordKey(modifiers: carbonModifiers, keyCode: keyCode)
        }
    }
    
    /// 处理修饰键变化事件
    private func handleFlagsChanged(_ event: NSEvent) {
        let modifiers = event.modifierFlags
        currentModifiers = carbonModifiersFromCocoaModifiers(modifiers)
        
        // 检查是否为单独的右侧修饰键
        if checkForRightModifierKey(modifiers: modifiers, keyCode: event.keyCode) {
            return
        }
    }
    
    /// 检查是否为右侧修饰键（右 Command 或右 Option）
    private func checkForRightModifierKey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        if modifiers.contains(.command) && keyCode == 54 {  // 右 Command
            recordKey(modifiers: 0x100010, keyCode: 0)
            return true
        } else if modifiers.contains(.option) && keyCode == 61 {  // 右 Option
            recordKey(modifiers: 0x100040, keyCode: 0)
            return true
        }
        return false
    }
    
    /// 记录快捷键并停止录制
    private func recordKey(modifiers: UInt32, keyCode: UInt32) {
        stopRecording()
        onKeyRecorded?(modifiers, keyCode)
    }
    
    /// 验证按键是否有效
    private func isValidKey(_ keyCode: UInt32) -> Bool {
        let validKeys: [UInt32] = [
            // 特殊键
            UInt32(kVK_Space), UInt32(kVK_Return), UInt32(kVK_Escape), UInt32(kVK_Tab),
            
            // 功能键
            UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
            UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
            UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
            
            // 字母键 A-Z
            UInt32(kVK_ANSI_A), UInt32(kVK_ANSI_B), UInt32(kVK_ANSI_C), UInt32(kVK_ANSI_D),
            UInt32(kVK_ANSI_E), UInt32(kVK_ANSI_F), UInt32(kVK_ANSI_G), UInt32(kVK_ANSI_H),
            UInt32(kVK_ANSI_I), UInt32(kVK_ANSI_J), UInt32(kVK_ANSI_K), UInt32(kVK_ANSI_L),
            UInt32(kVK_ANSI_M), UInt32(kVK_ANSI_N), UInt32(kVK_ANSI_O), UInt32(kVK_ANSI_P),
            UInt32(kVK_ANSI_Q), UInt32(kVK_ANSI_R), UInt32(kVK_ANSI_S), UInt32(kVK_ANSI_T),
            UInt32(kVK_ANSI_U), UInt32(kVK_ANSI_V), UInt32(kVK_ANSI_W), UInt32(kVK_ANSI_X),
            UInt32(kVK_ANSI_Y), UInt32(kVK_ANSI_Z),
            
            // 数字键 0-9
            UInt32(kVK_ANSI_0), UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
            UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7),
            UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9),
        ]
        
        return validKeys.contains(keyCode)
    }
    
    /// 将 Cocoa 修饰键转换为 Carbon 修饰键
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
    
    // MARK: - Cleanup
    deinit {
        stopRecording()
    }
}
