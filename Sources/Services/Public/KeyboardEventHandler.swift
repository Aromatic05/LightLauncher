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

@MainActor
final class KeyboardEventHandler {
    static let shared = KeyboardEventHandler()
    let keyEventPublisher = PassthroughSubject<KeyEvent, Never>()

    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var lastFlags: NSEvent.ModifierFlags = []

    private static let alwaysInterceptedKeys: Set<KeyEvent> = [
        .arrowUp,
        .arrowDown,
        .enter,
        .escape,
    ]

    private var currentModeInterceptedKeys: Set<KeyEvent> = []

    private init() {}

    func updateInterceptionRules(for modeKeys: Set<KeyEvent>) {
        currentModeInterceptedKeys = modeKeys
    }

    func startMonitoring() {
        stopMonitoring()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            self.checkFlags(eventFlags: event.modifierFlags)

            if let keyEvent = self.translateToKeyEvent(event), self.shouldIntercept(keyEvent) {
                self.keyEventPublisher.send(keyEvent)
                return nil
            }

            return event
        }

        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.checkFlags(eventFlags: event.modifierFlags)
            return event
        }
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

    private func shouldIntercept(_ keyEvent: KeyEvent) -> Bool {
        KeyboardEventHandler.alwaysInterceptedKeys.contains(keyEvent)
            || currentModeInterceptedKeys.contains(keyEvent)
    }

    private func checkFlags(eventFlags: NSEvent.ModifierFlags) {
        if eventFlags.contains(.command) != lastFlags.contains(.command) {
            keyEventPublisher.send(.commandFlagChanged(isPressed: eventFlags.contains(.command)))
        }

        if eventFlags.contains(.option) != lastFlags.contains(.option) {
            keyEventPublisher.send(.optionFlagChanged(isPressed: eventFlags.contains(.option)))
        }

        if eventFlags.contains(.control) != lastFlags.contains(.control) {
            keyEventPublisher.send(.controlFlagChanged(isPressed: eventFlags.contains(.control)))
        }

        lastFlags = eventFlags
    }

    private func translateToKeyEvent(_ event: NSEvent) -> KeyEvent? {
        switch event.keyCode {
        case 126:
            return .arrowUp
        case 125:
            return .arrowDown
        case 36, 76:
            let mods = event.modifierFlags.intersection([.command, .shift, .control, .option])
            return mods.isEmpty ? .enter : .enterWithModifiers(modifierRawValue: mods.rawValue)
        case 49:
            return .space
        case 53:
            return .escape
        default:
            if let chars = event.characters,
                let number = Int(chars),
                (0...9).contains(number),
                event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty
            {
                return .numeric(number)
            }
            return nil
        }
    }
}
