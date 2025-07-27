import SwiftUI
import AppKit
import Combine

// 1. 定义键盘事件的抽象契约（保持不变）
enum KeyEvent {
    case arrowUp
    case arrowDown
    case enter
    case space
    case escape
    case numeric(Int)
    case commandFlagChanged(isPressed: Bool)
    case optionFlagChanged(isPressed: Bool)
    case controlFlagChanged(isPressed: Bool)
}

// MARK: - KeyboardEventHandler
final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    let keyEventPublisher = PassthroughSubject<KeyEvent, Never>()

    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastFlags: NSEvent.ModifierFlags = []

    private init() {}

    func startMonitoring() {
        stopMonitoring()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            self.checkFlags(eventFlags: event.modifierFlags)
            if let keyEvent = self.translateToKeyEvent(event) {
                self.keyEventPublisher.send(keyEvent)
                return nil
            }
            return event
        }

        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            self.checkFlags(eventFlags: event.modifierFlags)
            return event
        }
    }

    /// 统一处理修饰键状态变化的辅助函数 (***这里是主要修改点***)
    private func checkFlags(eventFlags: NSEvent.ModifierFlags) {
        // 检查 Command 键
        if eventFlags.contains(.command) != self.lastFlags.contains(.command) {
            let isPressed = eventFlags.contains(.command)
            self.keyEventPublisher.send(.commandFlagChanged(isPressed: isPressed))
        }

        // 新增：检查 Option 键
        if eventFlags.contains(.option) != self.lastFlags.contains(.option) {
            let isPressed = eventFlags.contains(.option)
            self.keyEventPublisher.send(.optionFlagChanged(isPressed: isPressed))
        }

        // 新增：检查 Control 键
        if eventFlags.contains(.control) != self.lastFlags.contains(.control) {
            let isPressed = eventFlags.contains(.control)
            self.keyEventPublisher.send(.controlFlagChanged(isPressed: isPressed))
        }

        // 更新最后的状态记录
        self.lastFlags = eventFlags
    }

    private func translateToKeyEvent(_ event: NSEvent) -> KeyEvent? {
        // 这个函数保持不变，它只负责翻译非修饰键
        switch event.keyCode {
        case 126: return .arrowUp
        case 125: return .arrowDown
        case 36, 76: return .enter
        case 49: return .space
        case 53: return .escape
        default:
            if let chars = event.characters,
               let number = Int(chars),
               (0...9).contains(number),
               event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty {
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