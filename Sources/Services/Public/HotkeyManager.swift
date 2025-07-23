import Foundation
import Carbon
import AppKit

/// 负责全局热键的注册、处理和更新。
///
/// 封装了与 Carbon 框架交互的底层细节，包括对常规热键和“仅修饰键”热键的分别处理。
/// 它通过一个闭包与外部通信，当热键被触发时，执行该闭包。
@MainActor
final class HotkeyManager {

    // MARK: - 属性
    
    /// 对已注册热键的引用，用于后续注销。
    private var hotKeyRef: EventHotKeyRef?
    /// 对事件处理器的引用，用于常规热键。
    private var eventHandler: EventHandlerRef?
    /// 对修饰键状态变化的监听器，用于“仅修饰键”热键。
    private var modifierMonitor: Any?
    
    /// 当前的热键配置。
    private var hotkeyConfig: HotKey
    /// 热键触发时需要执行的动作。
    private let toggleAction: () -> Void

    // MARK: - 初始化
    
    init(config: HotKey, toggleAction: @escaping () -> Void) {
        self.hotkeyConfig = config
        self.toggleAction = toggleAction
    }

    // MARK: - 公开方法
    
    /// 注册初始的全局热键。
    public func registerInitialHotkey() {
        setupGlobalHotkey()
    }
    
    /// 当热键配置变化时，更新全局热键。
    public func updateHotkey(with newConfig: HotKey) {
        self.hotkeyConfig = newConfig
        
        // 1. 先注销所有旧的热键和监听器。
        unregisterHotkey()
        
        // 2. 重新注册新的热键。
        setupGlobalHotkey()
    }

    // MARK: - 私有热键设置逻辑
    
    private func setupGlobalHotkey() {
        let hotKeyId = EventHotKeyID(signature: "htk1".fourCharCodeValue, id: 1)
        var hotKeyRef: EventHotKeyRef?
        
        // 对于“仅修饰键”，我们注册一个虚拟的、几乎不会被按到的键（如F13），
        // 真正的逻辑依赖于后续的 flagsChanged 事件监听。
        let keyCode = hotkeyConfig.keyCode == 0 ? UInt32(kVK_F13) : hotkeyConfig.keyCode
        
        let status = RegisterEventHotKey(
            keyCode,
            hotkeyConfig.modifiers,
            hotKeyId,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            
            // 根据热键类型，设置不同的处理方式。
            if hotkeyConfig.keyCode == 0 {
                setupModifierOnlyHotkey()
            } else {
                setupRegularHotkey()
            }
        }
    }
    
    /// 为常规组合键（如 Cmd+Space）设置事件处理器。
    private func setupRegularHotkey() {
        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
        
        let callback: EventHandlerProcPtr = { _, _, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            // 在主线程异步执行动作，避免阻塞事件循环。
            DispatchQueue.main.async {
                manager.handleHotKeyPressed()
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &self.eventHandler
        )
    }
    
    /// 为“仅修饰键”（如单独按下左Command）设置事件监听器。
    private func setupModifierOnlyHotkey() {
        self.modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierOnlyHotkey(event)
        }
    }
    
    /// 处理“仅修饰键”的释放事件。
    private func handleModifierOnlyHotkey(_ event: NSEvent) {
        // 检查是否是我们设置的那个修饰键被“释放”了。
        let isModifierReleased = (UInt32(event.modifierFlags.rawValue) & hotkeyConfig.modifiers) == 0
        // 检查是否还有其他修饰键被按住。
        let noOtherModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
        
        if isModifierReleased && noOtherModifiers {
            handleHotKeyPressed()
        }
    }
    
    /// 热键被触发时的统一处理入口。
    private func handleHotKeyPressed() {
        // 调用注入的闭包，执行例如“切换窗口显示”的动作。
        toggleAction()
    }
    
    /// 注销当前所有的热键和监听器。
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let modifierMonitor = modifierMonitor {
            NSEvent.removeMonitor(modifierMonitor)
            self.modifierMonitor = nil
        }
    }
}

// MARK: - 辅助类型

/// 简单的热键配置数据结构，可以从 ConfigManager 获取。
struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
}

/// 将字符串转换为 FourCharCode，用于热键签名。
extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { bytes in
                for i in 0..<min(4, data.count) {
                    result = (result << 8) + FourCharCode(bytes[i])
                }
            }
        }
        return result
    }
}
