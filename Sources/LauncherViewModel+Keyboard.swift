// 在 LauncherViewModel+Keyboard.swift 扩展文件中

import Foundation
import Combine

// MARK: - Keyboard Handling
extension LauncherViewModel {
    // --- 订阅方法 (保持不变) ---
    func setupKeyboardSubscription() {
        KeyboardEventHandler.shared.keyEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(keyEvent: event)
            }
            .store(in: &cancellables)
    }

    /// **重构后的核心分发逻辑**
    private func handle(keyEvent: KeyEvent) {
        // 步骤 1: 优先处理 ViewModel 负责的、绝对通用的全局事件
        switch keyEvent {
        case .arrowUp:
            if showCommandSuggestions {
                moveCommandSuggestionUp()
            } else {
                moveSelectionUp()
            }
            return // 事件已处理，流程结束

        case .arrowDown:
            if showCommandSuggestions {
                moveCommandSuggestionDown()
            } else {
                moveSelectionDown()
            }
            return // 事件已处理，流程结束

        case .escape:
            NotificationCenter.default.post(name: .hideWindowWithoutActivating, object: nil)
            return // 事件已处理，流程结束

        default:
            // 其他事件继续传递
            break
        }
        
        // 步骤 2: 更新修饰键的状态，为 Controller 提供判断依据
        updateModifierKeyState(for: keyEvent)

        // 步骤 3: 将所有其他事件委托给 activeController
        // 如果 Controller 处理了，就到此为止
        if activeController?.handle(keyEvent: keyEvent) == true {
            return
        }

        // 步骤 4: 如果 Controller 也不处理，则没有更多操作
    }

    /// 更新修饰键状态的辅助函数 (保持不变)
    private func updateModifierKeyState(for keyEvent: KeyEvent) {
        switch keyEvent {
        case .commandFlagChanged(let isPressed): isCommandPressed = isPressed
        case .optionFlagChanged(let isPressed): isOptionPressed = isPressed
        case .controlFlagChanged(let isPressed): isControlPressed = isPressed
        default: break
        }
    }
}