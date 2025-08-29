import AppKit
import Combine
import SwiftUI

/// 定义键盘事件的抽象契约，必须是 Hashable 以便用作 Set 的元素
enum KeyEvent: Hashable {
    case arrowUp
    case arrowDown
    case enter
    case space
    case escape
    case numeric(Int)
    case commandFlagChanged(isPressed: Bool)
    case optionFlagChanged(isPressed: Bool)
    case controlFlagChanged(isPressed: Bool)
    case enterWithModifiers(modifierRawValue: UInt)
}

// MARK: - KeyboardEventHandler
@MainActor
final class KeyboardEventHandler {
    static let shared = KeyboardEventHandler()
    let keyEventPublisher = PassthroughSubject<KeyEvent, Never>()

    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastFlags: NSEvent.ModifierFlags = []

    // 1. 定义一个私有的、静态的集合，存放总是要拦截的“原型”键
    private static let alwaysInterceptedKeys: Set<KeyEvent> = [
        .arrowUp,
        .arrowDown,
        .enter,
        .escape,
    ]

    // 2. 一个变量，用于存储当前模式声明要拦截的“原型”键
    private var currentModeInterceptedKeys: Set<KeyEvent> = []

    private init() {}

    /// **新增：一个公共方法，用于让 ViewModel 更新拦截规则**
    func updateInterceptionRules(for modeKeys: Set<KeyEvent>) {
        self.currentModeInterceptedKeys = modeKeys
    }

    func startMonitoring() {
        stopMonitoring()
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // 首先，异步地将修饰键状态的变化通过 publisher 发布出去
            // 这不应该影响按键事件的拦截决策
            self.checkFlags(eventFlags: event.modifierFlags)

            // 然后，处理按键事件
            if let keyEvent = self.translateToKeyEvent(event) {
                // **关键决策逻辑**
                if self.shouldIntercept(keyEvent) {
                    // 如果应该拦截，就发布按键事件并消耗掉
                    self.keyEventPublisher.send(keyEvent)
                    return nil
                }
            }

            // 否则，直接放行事件，让它可以被输入到文本框等
            return event
        }

        // flagsChangedMonitor 的作用仅仅是触发 checkFlags
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.checkFlags(eventFlags: event.modifierFlags)
            // 总是放行修饰键事件本身
            return event
        }
    }

    /// **新增：决策辅助函数**
    private func shouldIntercept(_ keyEvent: KeyEvent) -> Bool {
        // 创建一个无关联值的“原型”版本用于查询规则
        let keyPrototype = keyEvent
        // 如果“原型”在全局列表或当前模式列表中，则拦截
        return KeyboardEventHandler.alwaysInterceptedKeys.contains(keyPrototype)
            || self.currentModeInterceptedKeys.contains(keyPrototype)
    }

    /// 统一处理修饰键状态变化的辅助函数
    private func checkFlags(eventFlags: NSEvent.ModifierFlags) {
        // 检查 Command 键
        if eventFlags.contains(.command) != self.lastFlags.contains(.command) {
            let isPressed = eventFlags.contains(.command)
            self.keyEventPublisher.send(.commandFlagChanged(isPressed: isPressed))
        }

        // 检查 Option 键
        if eventFlags.contains(.option) != self.lastFlags.contains(.option) {
            let isPressed = eventFlags.contains(.option)
            self.keyEventPublisher.send(.optionFlagChanged(isPressed: isPressed))
        }

        // 检查 Control 键
        if eventFlags.contains(.control) != self.lastFlags.contains(.control) {
            let isPressed = eventFlags.contains(.control)
            self.keyEventPublisher.send(.controlFlagChanged(isPressed: isPressed))
        }

        // 更新最后的状态记录
        self.lastFlags = eventFlags
    }

    private func translateToKeyEvent(_ event: NSEvent) -> KeyEvent? {
        // 这个函数负责将底层的 NSEvent 翻译成我们自己的 KeyEvent
        switch event.keyCode {
        case 126: return .arrowUp
        case 125: return .arrowDown
        case 36, 76:
            // enter 键，判断修饰键
            let mods = event.modifierFlags.intersection([.command, .shift, .control, .option])
            if !mods.isEmpty {
                return .enterWithModifiers(modifierRawValue: mods.rawValue)
            } else {
                return .enter
            }
        case 49: return .space
        case 53: return .escape
        default:
            // 检查是否为无修饰键的数字
            if let chars = event.characters,
                let number = Int(chars),
                (0...9).contains(number),
                event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty
            {
                return .numeric(number)
            }
        }
        return nil
    }

    func stopMonitoring() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
    }
}
