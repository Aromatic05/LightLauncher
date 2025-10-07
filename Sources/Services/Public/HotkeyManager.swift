import AppKit
import Foundation

// MARK: - Notification Definitions
extension Notification.Name {
    static let mainHotkeyTriggered = Notification.Name("com.lightlauncher.mainHotkeyTriggered")
    static let customHotkeyTriggered = Notification.Name("com.lightlauncher.customHotkeyTriggered")
}

// MARK: - Hotkey Manager (CGEvent Tap Based)
@MainActor
final class HotkeyManager {
    // 1. 使用单例模式
    static let shared = HotkeyManager()

    // 将所有 static var 改为实例变量
    private var registeredHotkeys: [UInt32: RegisteredHotkey] = [:]
    private var customHotKeyConfigMap: [UInt32: CustomHotKeyConfig] = [:]

    private var tapState: TapState = .stopped
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    private var physicalModifierKeys: Set<UInt16> = []
    private var modifierOnlyStates: [UInt32: ModifierOnlyState] = [:]

    private var reconnectTask: Task<Void, Never>?

    // 构造函数私有化，确保单例
    private init() {}

    // MARK: - Constants
    private let tapMask = CGEventMask(
        (1 << Int(CGEventType.flagsChanged.rawValue)) |
        (1 << Int(CGEventType.keyDown.rawValue))
    )
    private let tapRunLoopMode = CFRunLoopMode.commonModes

    // MARK: - Types
    private struct RegisteredHotkey {
        let hotkey: HotKey
        let id: UInt32
        let isMain: Bool
    }

    private struct ModifierOnlyState {
        var matchedHotkey: HotKey?
        var interferenceDetected: Bool = false
    }

    // Sendable 确保可以跨线程安全传递
    fileprivate struct TapEventSnapshot: Sendable {
        let typeRaw: UInt32
        let keyCode: UInt16
        let flagsRaw: UInt64

        var type: CGEventType? {
            CGEventType(rawValue: typeRaw)
        }
    }

    private enum TapState {
        case stopped
        case starting
        case running
        case failed
    }

    private var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    // MARK: - Public API (改为实例方法)
    func registerAll(mainHotkey: HotKey, customHotkeys: [CustomHotKeyConfig]) {
        unregisterAll()

        let mainId: UInt32 = 1
        registeredHotkeys[mainId] = RegisteredHotkey(hotkey: mainHotkey, id: mainId, isMain: true)

        for config in customHotkeys {
            let id = UInt32(truncatingIfNeeded: config.name.hashValue)
            registeredHotkeys[id] = RegisteredHotkey(hotkey: config.hotkey, id: id, isMain: false)
            customHotKeyConfigMap[id] = config
        }

        startEventTapIfNeeded()

        print("[HotkeyManager] Registered hotkeys: main=\(mainHotkey.description()), custom=\(customHotkeys.count)")
    }

    func unregisterAll() {
        registeredHotkeys.removeAll()
        customHotKeyConfigMap.removeAll()
        modifierOnlyStates.removeAll()
        physicalModifierKeys.removeAll()

        stopEventTapIfNeeded()

        print("[HotkeyManager] All hotkeys unregistered")
    }

    func getConfig(for id: UInt32) -> CustomHotKeyConfig? {
        customHotKeyConfigMap[id]
    }

    // MARK: - Event Tap Lifecycle (改为实例方法)
    private func startEventTapIfNeeded() {
        reconnectTask?.cancel()
        reconnectTask = nil

        guard eventTap == nil else {
            if tapState != .running {
                resumeEventTap()
            }
            return
        }

        guard isAccessibilityTrusted else {
            print("[HotkeyManager] ⚠️ Accessibility permission not granted. Hotkeys will not function.")
            tapState = .failed
            return
        }

        guard !registeredHotkeys.isEmpty else {
            tapState = .stopped
            return
        }

        tapState = .starting

        // 2. 将 self (单例实例) 的指针传递给 userInfo
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: tapMask,
            callback: hotkeyManagerTapCallback, // 注意函数名变化
            userInfo: userInfo
        ) else {
            print("[HotkeyManager] ✗ Failed to create event tap")
            tapState = .failed
            scheduleReconnect()
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, tapRunLoopMode)
            CGEvent.tapEnable(tap: tap, enable: true)
            tapState = .running
            print("[HotkeyManager] ✓ Event tap started")
        } else {
            print("[HotkeyManager] ✗ Failed to create run loop source for event tap")
            tapState = .failed
            scheduleReconnect()
        }
    }

    private func resumeEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        tapState = .running
        print("[HotkeyManager] ℹ️ Event tap resumed")
    }

    private func stopEventTapIfNeeded() {
        reconnectTask?.cancel()
        reconnectTask = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, tapRunLoopMode)
        }

        eventTap = nil
        eventTapRunLoopSource = nil
        tapState = .stopped
        print("[HotkeyManager] Event tap stopped")
    }

    private func scheduleReconnect(after delay: TimeInterval = 2.0) {
        reconnectTask?.cancel()
        guard !registeredHotkeys.isEmpty else { return }

        reconnectTask = Task {
            // Task 默认就在 @MainActor 上下文中了
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            startEventTapIfNeeded()
        }
    }

    fileprivate func handleTapDisabled() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] ℹ️ Event tap re-enabled after disable signal")
    }

    // MARK: - Event Handling
    fileprivate func processEvent(snapshot: TapEventSnapshot) {
        guard let type = snapshot.type else { return }

        switch type {
        case .flagsChanged:
            updatePhysicalModifierKeys(flagsRaw: snapshot.flagsRaw, keyCode: snapshot.keyCode)
            handleFlagsChanged(keyCode: snapshot.keyCode, flagsRaw: snapshot.flagsRaw)
        case .keyDown:
            handleKeyDown(keyCode: snapshot.keyCode, flagsRaw: snapshot.flagsRaw)
        default:
            break
        }
    }

    // MARK: - Flags Handling (Modifier Only)
    private func handleFlagsChanged(keyCode: UInt16, flagsRaw: UInt64) {
        let currentHotkey = HotKey.from(keyCode: keyCode, flagsRaw: flagsRaw, physicalKeys: physicalModifierKeys)
        let hasActiveModifiers = !physicalModifierKeys.isEmpty

        for (id, entry) in registeredHotkeys where entry.hotkey.isModifierOnly {
            var state = modifierOnlyStates[id, default: ModifierOnlyState()]

            if hasActiveModifiers {
                if entry.hotkey.rawValue == currentHotkey.rawValue {
                    if state.matchedHotkey == nil {
                        state.matchedHotkey = currentHotkey
                        state.interferenceDetected = false
                        print("[HotkeyManager] 🔽 Modifier pressed: \(currentHotkey.description()) [id=\(id)]")
                    }
                } else if state.matchedHotkey != nil {
                    state.interferenceDetected = true
                }
            } else if let matched = state.matchedHotkey {
                if !state.interferenceDetected {
                    triggerHotkey(id: id, isMain: entry.isMain)
                    print("[HotkeyManager] ⚡ ModifierOnly triggered: \(matched.description()) [id=\(id)]")
                } else {
                    print("[HotkeyManager] 🚫 ModifierOnly cancelled (interference)")
                }
                state = ModifierOnlyState()
            }

            modifierOnlyStates[id] = state
        }
    }

    // MARK: - Key Down Handling
    private func handleKeyDown(keyCode: UInt16, flagsRaw: UInt64) {
        let hotkey = HotKey.from(keyCode: keyCode, flagsRaw: flagsRaw, physicalKeys: physicalModifierKeys)

        for entry in registeredHotkeys.values {
            guard entry.hotkey.keyCode == hotkey.keyCode else { continue }

            if entry.hotkey.isModifierOnly {
                if var state = modifierOnlyStates[entry.id] {
                    state.interferenceDetected = true
                    modifierOnlyStates[entry.id] = state
                }
                continue
            }

            if entry.hotkey.hasSideSpecification {
                if entry.hotkey.rawValue == hotkey.rawValue {
                    triggerHotkey(id: entry.id, isMain: entry.isMain)
                    print("[HotkeyManager] ⚡ Hotkey triggered: \(entry.hotkey.description()) [id=\(entry.id)]")
                }
            } else if entry.hotkey.matchesIgnoringSide(hotkey) {
                triggerHotkey(id: entry.id, isMain: entry.isMain)
                print("[HotkeyManager] ⚡ Hotkey triggered: \(entry.hotkey.description()) [id=\(entry.id)]")
            }
        }
    }

    // MARK: - Modifier Key Tracking
    private func updatePhysicalModifierKeys(flagsRaw: UInt64, keyCode: UInt16) {
        let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.RawValue(truncatingIfNeeded: flagsRaw))

        let mapping: [(UInt16, NSEvent.ModifierFlags)] = [
            (UInt16(kVK_LeftCommand), .command),
            (UInt16(kVK_RightCommand), .command),
            (UInt16(kVK_LeftOption), .option),
            (UInt16(kVK_RightOption), .option),
            (UInt16(kVK_LeftShift), .shift),
            (UInt16(kVK_RightShift), .shift),
            (UInt16(kVK_Control), .control),
        ]

        for (physCode, flag) in mapping where physCode == keyCode {
            if flags.contains(flag) {
                physicalModifierKeys.insert(physCode)
            } else {
                physicalModifierKeys.remove(physCode)
            }
        }
    }
    // MARK: - Trigger
    private func triggerHotkey(id: UInt32, isMain: Bool) {
        if isMain {
            NotificationCenter.default.post(name: .mainHotkeyTriggered, object: nil)
        } else {
            NotificationCenter.default.post(name: .customHotkeyTriggered, object: nil, userInfo: ["hotkeyID": id])
        }
    }
}

// 3. 将回调函数移出类外，并变为一个普通的 private free function
private func hotkeyManagerTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // 4. 从 userInfo 恢复 HotkeyManager 实例
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in
            manager.handleTapDisabled()
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .flagsChanged || type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let snapshot = HotkeyManager.TapEventSnapshot(
        typeRaw: type.rawValue,
        keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
        flagsRaw: event.flags.rawValue
    )

    Task { @MainActor in
        // 5. 在 manager 实例上调用方法
        manager.processEvent(snapshot: snapshot)
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - CGEvent Utilities
// 这些辅助函数不依赖 HotkeyManager 的状态，可以保持原样
private extension HotKey {
    static func from(keyCode: UInt16, flagsRaw: UInt64, physicalKeys: Set<UInt16>) -> HotKey {
        let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.RawValue(truncatingIfNeeded: flagsRaw))
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        let shift = flags.contains(.shift)

        let isModifierKey = HotKey.isModifierKeyCode(keyCode)
        let hotKeyCode: UInt32 = isModifierKey ? 0 : UInt32(keyCode)

        var side: HotKey.Side = .any
        if command {
            if physicalKeys.contains(UInt16(kVK_LeftCommand)) { side = .left }
            else if physicalKeys.contains(UInt16(kVK_RightCommand)) { side = .right }
        } else if option {
            if physicalKeys.contains(UInt16(kVK_LeftOption)) { side = .left }
            else if physicalKeys.contains(UInt16(kVK_RightOption)) { side = .right }
        } else if shift {
            if physicalKeys.contains(UInt16(kVK_LeftShift)) { side = .left }
            else if physicalKeys.contains(UInt16(kVK_RightShift)) { side = .right }
        }

        return HotKey(
            keyCode: hotKeyCode,
            command: command,
            option: option,
            control: control,
            shift: shift,
            side: side
        )
    }

    func matchesIgnoringSide(_ other: HotKey) -> Bool {
        let normalizedSelf = HotKey(
            keyCode: keyCode,
            command: hasCommand,
            option: hasOption,
            control: hasControl,
            shift: hasShift,
            side: .any
        )
        let normalizedOther = HotKey(
            keyCode: other.keyCode,
            command: other.hasCommand,
            option: other.hasOption,
            control: other.hasControl,
            shift: other.hasShift,
            side: .any
        )
        return normalizedSelf.rawValue == normalizedOther.rawValue
    }
}

// MARK: - String + FourCharCode
private extension String {
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