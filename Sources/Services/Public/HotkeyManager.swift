import AppKit
import Carbon
import Foundation

// MARK: - 全局 C 回调函数
private func sharedHotKeyHandler(
    nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return noErr }

    var hotKeyId = EventHotKeyID()
    // 从事件中提取出热键的 ID
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

/// 一个纯静态类，用于管理所有全局热键。
/// 所有热键共享一个统一的事件处理器，通过不同的签名来区分。
@MainActor
final class HotkeyManager {
    // 防止被实例化
    private init() {}

    // MARK: - 静态属性

    private static let mainHotkeySignature = "mhk1".fourCharCodeValue
    private static let customHotkeySignature = "cthk".fourCharCodeValue

    private static var registeredHotkeys: [EventHotKeyRef] = []
    private static var sharedEventHandler: EventHandlerRef?
    private static var modifierMonitor: Any?
    private static var customHotKeyConfigMap: [UInt32: CustomHotKeyConfig] = [:]

    // MARK: - 统一的注册与注销

    static func registerAll(mainHotkey: HotKey, customHotkeys: [CustomHotKeyConfig]) {
        unregisterAll()

        if sharedEventHandler == nil {
            setupSharedEventHandler()
        }

        if mainHotkey.keyCode == 0 {
            registerModifierOnlyMainHotkey(config: mainHotkey)
        } else {
            register(
                keyCode: mainHotkey.keyCode, modifiers: mainHotkey.modifiers, id: 1,
                signature: mainHotkeySignature)
        }

        for config in customHotkeys {
            let id = UInt32(config.name.hashValue & 0xFFFF_FFFF)
            customHotKeyConfigMap[id] = config
            register(
                keyCode: config.keyCode, modifiers: config.modifiers, id: id,
                signature: customHotkeySignature)
        }
    }

    static func unregisterAll() {
        for hotkeyRef in registeredHotkeys {
            UnregisterEventHotKey(hotkeyRef)
        }
        registeredHotkeys.removeAll()
        customHotKeyConfigMap.removeAll()

        if let modifierMonitor = modifierMonitor {
            NSEvent.removeMonitor(modifierMonitor)
            self.modifierMonitor = nil
        }
    }

    static func getConfig(for id: UInt32) -> CustomHotKeyConfig? {
        return customHotKeyConfigMap[id]
    }

    fileprivate static func processHotkey(with id: EventHotKeyID) {
        print("Hotkey triggered with signature: \(id.signature), id: \(id.id)")
        switch id.signature {
        case mainHotkeySignature:
            NotificationCenter.default.post(name: .mainHotkeyTriggered, object: nil)
        case customHotkeySignature:
            NotificationCenter.default.post(
                name: .customHotkeyTriggered,
                object: nil,
                userInfo: ["hotkeyID": id.id]
            )
        default:
            break
        }
    }

    // MARK: - 私有实现

    private static func register(
        keyCode: UInt32, modifiers: UInt32, id: UInt32, signature: FourCharCode
    ) {
        let hotKeyId = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef? = nil

        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr, let ref = hotKeyRef {
            registeredHotkeys.append(ref)
        } else {
            print("Error: Failed to register hotkey with id \(id). Status: \(status)")
        }
    }

    private static func registerModifierOnlyMainHotkey(config: HotKey) {
        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let isModifierReleased = (UInt32(event.modifierFlags.rawValue) & config.modifiers) == 0
            let noOtherModifiers = event.modifierFlags.intersection([
                .command, .option, .control, .shift,
            ]).isEmpty

            if isModifierReleased && noOtherModifiers {
                NotificationCenter.default.post(name: .mainHotkeyTriggered, object: nil)
            }
        }
    }

    private static func setupSharedEventHandler() {
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        InstallEventHandler(
            GetApplicationEventTarget(), sharedHotKeyHandler, 1, &eventTypes, nil,
            &sharedEventHandler)
    }
}

// MARK: - 辅助类型 (保持不变)
struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
}

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
