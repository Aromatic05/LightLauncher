import AppKit
import Carbon.HIToolbox
import Foundation

// MARK: - 全局 C 回调函数
private func sharedHotKeyHandler(
    nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return noErr }

    var hotKeyId = EventHotKeyID()
    guard
        GetEventParameter(
            event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil,
            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyId) == noErr
    else {
        return noErr
    }

    DispatchQueue.main.async {
        HotkeyManager.processHotkey(with: hotKeyId)
    }

    return noErr
}

// MARK: - 通知定义
extension Notification.Name {
    static let mainHotkeyTriggered = Notification.Name("com.lightlauncher.mainHotkeyTriggered")
    static let customHotkeyTriggered = Notification.Name("com.lightlauncher.customHotkeyTriggered")
}

/**
 全局热键管理器（三层架构）
 
 Layer 1: Carbon 注册 - 普通组合键（无侧别要求）
 Layer 2: NSEvent 监听 - 侧别组合键（需要区分左右）
 Layer 3: 专门监听 - 仅修饰键（带干扰检测）
 */
@MainActor
final class HotkeyManager {
    private init() {}

    // MARK: - 静态属性
    
    private static let mainHotkeySignature = "mhk1".fourCharCodeValue
    private static let customHotkeySignature = "cthk".fourCharCodeValue

    // Layer 1: Carbon 注册的热键
    private static var carbonHotkeys: [(ref: EventHotKeyRef, id: UInt32, isMain: Bool)] = []
    private static var sharedEventHandler: EventHandlerRef?
    
    // Layer 2: NSEvent 监听的热键（侧别相关）- 需要 global 和 local 两个 monitor
    private static var nsEventHotkeys: [(hotkey: HotKey, id: UInt32, isMain: Bool, globalMonitor: Any?, localMonitor: Any?)] = []
    
    // Layer 3: 仅修饰键热键
    private static var modifierOnlyHotkey: (hotkey: HotKey, id: UInt32, isMain: Bool, globalMonitor: Any?, localMonitor: Any?)?
    
    // 物理按键跟踪（用于侧别检测）- 需要 global 和 local 两套监听器
    private static var physicalModifierKeys: Set<UInt16> = []
    private static var physicalKeyTracker: (globalFlags: Any?, localFlags: Any?, globalKeyDown: Any?, localKeyDown: Any?)?
    
    // 非修饰键按下标记（用于仅修饰键干扰检测）
    private static var hasNonModifierKeyPressed: Bool = false
    
    // 配置映射
    private static var customHotKeyConfigMap: [UInt32: CustomHotKeyConfig] = [:]

    // MARK: - 公共 API
    
    /// 注册所有热键
    static func registerAll(mainHotkey: HotKey, customHotkeys: [CustomHotKeyConfig]) {
        unregisterAll()
        print("[HotkeyManager] Registering main: \(mainHotkey.description()), custom: \(customHotkeys.count) hotkeys")
        
        // 启动物理按键跟踪（Layer 2 和 Layer 3 都需要）
        setupPhysicalKeyTracker()
        
        // 注册主热键
        registerHotkey(hotkey: mainHotkey, id: 1, isMain: true)
        
        // 注册自定义热键
        for config in customHotkeys {
            let hotkey = config.hotkey
            let id = UInt32(config.name.hashValue & 0xFFFF_FFFF)
            customHotKeyConfigMap[id] = config
            registerHotkey(hotkey: hotkey, id: id, isMain: false)
        }
        
        print("[HotkeyManager] Registration complete: Carbon=\(carbonHotkeys.count), NSEvent=\(nsEventHotkeys.count), ModifierOnly=\(modifierOnlyHotkey != nil ? 1 : 0)")
    }
    
    /// 注销所有热键
    static func unregisterAll() {
        // 清理 Carbon 热键
        for (ref, _, _) in carbonHotkeys {
            UnregisterEventHotKey(ref)
        }
        carbonHotkeys.removeAll()
        
        // 清理 NSEvent 热键
        for (_, _, _, globalMonitor, localMonitor) in nsEventHotkeys {
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        nsEventHotkeys.removeAll()
        
        // 清理仅修饰键热键
        if let (_, _, _, globalMonitor, localMonitor) = modifierOnlyHotkey {
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
            modifierOnlyHotkey = nil
        }
        
        // 清理物理按键跟踪
        if let (globalFlags, localFlags, globalKeyDown, localKeyDown) = physicalKeyTracker {
            if let monitor = globalFlags {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = localFlags {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = globalKeyDown {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = localKeyDown {
                NSEvent.removeMonitor(monitor)
            }
            physicalKeyTracker = nil
        }
        
        physicalModifierKeys.removeAll()
        customHotKeyConfigMap.removeAll()
        hasNonModifierKeyPressed = false
        
        print("[HotkeyManager] All hotkeys unregistered")
    }
    
    static func getConfig(for id: UInt32) -> CustomHotKeyConfig? {
        return customHotKeyConfigMap[id]
    }

    // MARK: - 核心注册逻辑
    
    private static func registerHotkey(hotkey: HotKey, id: UInt32, isMain: Bool) {
        guard hotkey.isValid else {
            print("[HotkeyManager] ⚠️ Invalid hotkey: \(hotkey.description())")
            return
        }
        
        if hotkey.isModifierOnly {
            // Layer 3: 仅修饰键
            registerModifierOnly(hotkey: hotkey, id: id, isMain: isMain)
        } else if hotkey.hasSideSpecification {
            // Layer 2: 侧别相关组合键
            registerWithNSEvent(hotkey: hotkey, id: id, isMain: isMain)
        } else {
            // Layer 1: 普通组合键
            registerWithCarbon(hotkey: hotkey, id: id, isMain: isMain)
        }
    }
    
    // MARK: - Layer 1: Carbon 注册
    
    private static func registerWithCarbon(hotkey: HotKey, id: UInt32, isMain: Bool) {
        if sharedEventHandler == nil {
            setupSharedEventHandler()
        }
        
        let signature = isMain ? mainHotkeySignature : customHotkeySignature
        let hotKeyId = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef? = nil
        
        let carbonMods = hotkey.toCarbonMask()
        let status = RegisterEventHotKey(
            hotkey.keyCode, carbonMods, hotKeyId,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            carbonHotkeys.append((ref, id, isMain))
            print("[HotkeyManager] ✓ Carbon registered: \(hotkey.description()) [id=\(id)]")
        } else {
            print("[HotkeyManager] ✗ Carbon failed: \(hotkey.description()) [status=\(status)]")
        }
    }
    
    private static func setupSharedEventHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            )
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            sharedHotKeyHandler,
            1,
            &eventTypes,
            nil,
            &sharedEventHandler
        )
    }
    
    // MARK: - Layer 2: NSEvent 监听（侧别组合键）
    
    private static func registerWithNSEvent(hotkey: HotKey, id: UInt32, isMain: Bool) {
        // 共享的匹配逻辑
        let matchAndTrigger: (NSEvent) -> Void = { event in
            // 1. 检查 keyCode 是否匹配
            guard UInt32(event.keyCode) == hotkey.keyCode else { return }
            
            // 2. 从物理按键集合计算当前修饰键（含侧别）
            let currentHotkey = HotKey.from(event: event, physicalKeys: physicalModifierKeys)
            
            // 3. 精确匹配（包括侧别）
            guard currentHotkey.rawValue == hotkey.rawValue else { return }
            
            // 4. 触发
            print("[HotkeyManager] ⚡ NSEvent triggered: \(hotkey.description()) [id=\(id)]")
            triggerHotkey(id: id, isMain: isMain)
        }
        
        // Global monitor - 监听其他应用的事件
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            matchAndTrigger(event)
        }
        
        // Local monitor - 拦截本应用的事件
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 1. 检查 keyCode 是否匹配
            guard UInt32(event.keyCode) == hotkey.keyCode else { return event }
            
            // 2. 从物理按键集合计算当前修饰键（含侧别）
            let currentHotkey = HotKey.from(event: event, physicalKeys: physicalModifierKeys)
            
            // 3. 精确匹配（包括侧别）
            guard currentHotkey.rawValue == hotkey.rawValue else { return event }
            
            // 4. 触发并拦截事件
            print("[HotkeyManager] ⚡ NSEvent (local) triggered: \(hotkey.description()) [id=\(id)]")
            triggerHotkey(id: id, isMain: isMain)
            return nil  // 拦截事件，不让它继续传播
        }
        
        nsEventHotkeys.append((hotkey, id, isMain, globalMonitor, localMonitor))
        print("[HotkeyManager] ✓ NSEvent registered (global + local): \(hotkey.description()) [id=\(id)]")
    }
    
    // MARK: - Layer 3: 仅修饰键（带干扰检测）
    
    private static func registerModifierOnly(hotkey: HotKey, id: UInt32, isMain: Bool) {
        var lastMatchedModifiers: HotKey? = nil
        
        // 共享的处理逻辑
        let handleFlagsChanged: (NSEvent) -> Void = { event in
            let currentHotkey = HotKey.from(event: event, physicalKeys: physicalModifierKeys)
            
            // 按下阶段：记录匹配
            if currentHotkey.rawValue == hotkey.rawValue {
                lastMatchedModifiers = currentHotkey
                hasNonModifierKeyPressed = false  // 重置干扰标记
                print("[HotkeyManager] 🔽 Modifier pressed: \(currentHotkey.description())")
            }
            
            // 释放阶段：检测触发
            if let matched = lastMatchedModifiers {
                // 所有修饰键都释放了
                let allModifiersReleased = !currentHotkey.hasModifiers
                
                // 期间没有其他按键按下
                let noInterference = !hasNonModifierKeyPressed
                
                if allModifiersReleased {
                    if noInterference {
                        print("[HotkeyManager] ⚡ ModifierOnly triggered: \(matched.description()) [id=\(id)]")
                        triggerHotkey(id: id, isMain: isMain)
                    } else {
                        print("[HotkeyManager] 🚫 ModifierOnly cancelled: interference detected")
                    }
                    lastMatchedModifiers = nil
                }
            }
        }
        
        // Global monitor
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlagsChanged(event)
        }
        
        // Local monitor
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlagsChanged(event)
            return event  // 不拦截 flagsChanged 事件
        }
        
        modifierOnlyHotkey = (hotkey, id, isMain, globalMonitor, localMonitor)
        print("[HotkeyManager] ✓ ModifierOnly registered (global + local): \(hotkey.description()) [id=\(id)]")
    }
    
    // MARK: - 物理按键跟踪
    
    private static func setupPhysicalKeyTracker() {
        // Global monitor: 跟踪 flagsChanged 以维护物理修饰键集合
        let globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            updatePhysicalModifierKeys(event: event)
        }
        
        // Local monitor: 跟踪 flagsChanged
        let localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            updatePhysicalModifierKeys(event: event)
            return event
        }
        
        // Global monitor: 跟踪 keyDown 以检测非修饰键按下（用于干扰检测）
        let globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            if !isModifierKeyCode(code) {
                hasNonModifierKeyPressed = true
            }
        }
        
        // Local monitor: 跟踪 keyDown
        let localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            if !isModifierKeyCode(code) {
                hasNonModifierKeyPressed = true
            }
            return event
        }
        
        physicalKeyTracker = (globalFlagsMonitor, localFlagsMonitor, globalKeyDownMonitor, localKeyDownMonitor)
        print("[HotkeyManager] ✓ Physical key tracker started (global + local)")
    }
    
    private static func updatePhysicalModifierKeys(event: NSEvent) {
        let code = event.keyCode
        let flags = event.modifierFlags
        
        let modifierMapping: [(UInt16, NSEvent.ModifierFlags)] = [
            (UInt16(kVK_LeftCommand), .command),
            (UInt16(kVK_RightCommand), .command),
            (UInt16(kVK_LeftOption), .option),
            (UInt16(kVK_RightOption), .option),
            (UInt16(kVK_LeftShift), .shift),
            (UInt16(kVK_RightShift), .shift),
            (UInt16(kVK_Control), .control),
        ]
        
        for (physCode, flag) in modifierMapping {
            if code == physCode {
                if flags.contains(flag) {
                    physicalModifierKeys.insert(physCode)
                } else {
                    physicalModifierKeys.remove(physCode)
                }
                break
            }
        }
    }
    
    private static func isModifierKeyCode(_ code: UInt16) -> Bool {
        return code == UInt16(kVK_LeftCommand) ||
               code == UInt16(kVK_RightCommand) ||
               code == UInt16(kVK_LeftOption) ||
               code == UInt16(kVK_RightOption) ||
               code == UInt16(kVK_LeftShift) ||
               code == UInt16(kVK_RightShift) ||
               code == UInt16(kVK_Control)
    }
    
    // MARK: - 触发逻辑
    
    fileprivate static func processHotkey(with id: EventHotKeyID) {
        // Carbon 回调
        triggerHotkey(id: id.id, isMain: id.signature == mainHotkeySignature)
    }
    
    private static func triggerHotkey(id: UInt32, isMain: Bool) {
        if isMain {
            NotificationCenter.default.post(name: .mainHotkeyTriggered, object: nil)
        } else {
            NotificationCenter.default.post(
                name: .customHotkeyTriggered,
                object: nil,
                userInfo: ["hotkeyID": id]
            )
        }
    }
}

// MARK: - String Extension for Carbon FourCharCode
extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let bytes = ptr.bindMemory(to: UInt8.self)
                for i in 0..<min(4, bytes.count) {
                    result = (result << 8) + UInt32(bytes[i])
                }
            }
        }
        return result
    }
}
