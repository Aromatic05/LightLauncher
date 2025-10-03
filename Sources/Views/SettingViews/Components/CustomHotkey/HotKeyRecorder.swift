import SwiftUI

// MARK: - 快捷键录制管理器
/// 负责处理快捷键的录制逻辑，使用新的 HotKey 结构
class HotKeyRecorder: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var currentHotKey: HotKey?
    
    // MARK: - Private Properties
    private var globalMonitor: Any?
    private var localMonitor: Any?
    // 跟踪物理修饰键以区分左右
    private var physicalModifierKeys: Set<UInt16> = []
    
    // MARK: - Callbacks
    var onKeyRecorded: ((HotKey) -> Void)?
    var onRecordingCancelled: (() -> Void)?
    
    // MARK: - Public Methods
    
    /// 开始录制快捷键
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        currentHotKey = nil
        physicalModifierKeys.removeAll()
        
        // 添加全局事件监听器
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // 添加本地事件监听器（阻止事件继续传播以避免影响其他输入）
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

        physicalModifierKeys.removeAll()
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
        let keyCode = UInt16(event.keyCode)
        
        // 必须是有效按键
        guard isValidKey(keyCode) else { return }
        
        // 使用 HotKey.from(event:physicalKeys:) 构建热键
        let hotkey = HotKey.from(event: event, physicalKeys: physicalModifierKeys)
        
        // 必须有修饰键，或者是功能键
        let isFunctionKey = keyCode >= UInt16(kVK_F1) && keyCode <= UInt16(kVK_F12)
        let hasModifiers = hotkey.hasModifiers
        
        if hasModifiers || isFunctionKey {
            print("[HotKeyRecorder] keyDown recorded: \(hotkey.description())")
            recordKey(hotkey: hotkey)
        }
    }
    
    /// 处理修饰键变化事件
    private func handleFlagsChanged(_ event: NSEvent) {
        let modifiers = event.modifierFlags
        let code = event.keyCode

        // 更新物理修饰键集合
        let mapping: [(UInt16, NSEvent.ModifierFlags)] = [
            (UInt16(kVK_LeftCommand), .command),
            (UInt16(kVK_RightCommand), .command),
            (UInt16(kVK_LeftOption), .option),
            (UInt16(kVK_RightOption), .option),
            (UInt16(kVK_LeftShift), .shift),
            (UInt16(kVK_RightShift), .shift),
            (UInt16(kVK_Control), .control),
        ]

        var handled = false
        for (physCode, flag) in mapping {
            if code == physCode {
                if modifiers.contains(flag) {
                    physicalModifierKeys.insert(physCode)
                } else {
                    physicalModifierKeys.remove(physCode)
                }
                handled = true
                break
            }
        }

        // 检测仅修饰键（修饰键被释放且没有其他按键）
        if handled && !modifiers.contains([.command, .option, .control, .shift]) {
            // 所有修饰键都被释放，检查是否为仅修饰键热键
            if let hotkey = checkForModifierOnlyKey(code: code) {
                print("[HotKeyRecorder] modifier-only recorded: \(hotkey.description())")
                recordKey(hotkey: hotkey)
                return
            }
        }

        // 更新当前状态
        if !physicalModifierKeys.isEmpty {
            let tempHotkey = HotKey.from(event: event, physicalKeys: physicalModifierKeys)
            currentHotKey = tempHotkey
        } else {
            currentHotKey = nil
        }

        print("[HotKeyRecorder] flagsChanged keyCode=\(code) flags=\(modifiers) physical=\(physicalModifierKeys)")
    }
    
    /// 检查是否为仅修饰键（区分左右）
    private func checkForModifierOnlyKey(code: UInt16) -> HotKey? {
        // keyCode: 物理键码, command/option/control/shift: 布尔值, side: 侧别
        switch code {
        case UInt16(kVK_LeftCommand):
            return HotKey(keyCode: 0, command: true, side: .left)
        case UInt16(kVK_RightCommand):
            return HotKey(keyCode: 0, command: true, side: .right)
        case UInt16(kVK_LeftOption):
            return HotKey(keyCode: 0, option: true, side: .left)
        case UInt16(kVK_RightOption):
            return HotKey(keyCode: 0, option: true, side: .right)
        case UInt16(kVK_LeftShift):
            return HotKey(keyCode: 0, shift: true, side: .left)
        case UInt16(kVK_RightShift):
            return HotKey(keyCode: 0, shift: true, side: .right)
        case UInt16(kVK_Control):
            return HotKey(keyCode: 0, control: true, side: .any)
        default:
            return nil
        }
    }
    
    /// 记录快捷键并停止录制
    private func recordKey(hotkey: HotKey) {
        print("[HotKeyRecorder] recordKey: \(hotkey.description())")
        stopRecording()
        onKeyRecorded?(hotkey)
    }
    
    /// 验证按键是否有效
    private func isValidKey(_ keyCode: UInt16) -> Bool {
        let validKeys: [UInt16] = [
            // 特殊键
            UInt16(kVK_Space), UInt16(kVK_Return), UInt16(kVK_Escape), UInt16(kVK_Tab),
            
            // 功能键
            UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
            UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
            UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
            
            // 字母键 A-Z
            UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_B), UInt16(kVK_ANSI_C), UInt16(kVK_ANSI_D),
            UInt16(kVK_ANSI_E), UInt16(kVK_ANSI_F), UInt16(kVK_ANSI_G), UInt16(kVK_ANSI_H),
            UInt16(kVK_ANSI_I), UInt16(kVK_ANSI_J), UInt16(kVK_ANSI_K), UInt16(kVK_ANSI_L),
            UInt16(kVK_ANSI_M), UInt16(kVK_ANSI_N), UInt16(kVK_ANSI_O), UInt16(kVK_ANSI_P),
            UInt16(kVK_ANSI_Q), UInt16(kVK_ANSI_R), UInt16(kVK_ANSI_S), UInt16(kVK_ANSI_T),
            UInt16(kVK_ANSI_U), UInt16(kVK_ANSI_V), UInt16(kVK_ANSI_W), UInt16(kVK_ANSI_X),
            UInt16(kVK_ANSI_Y), UInt16(kVK_ANSI_Z),
            
            // 数字键 0-9
            UInt16(kVK_ANSI_0), UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3),
            UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_7),
            UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9),
        ]
        
        return validKeys.contains(keyCode)
    }
    
    // MARK: - Cleanup
    deinit {
        stopRecording()
    }
}
