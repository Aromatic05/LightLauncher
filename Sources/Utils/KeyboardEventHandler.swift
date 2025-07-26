import SwiftUI
import AppKit
import Combine

// MARK: - KeyboardEventHandler
final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    weak var viewModel: LauncherViewModel?
    private var keyDownMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var currentMode: LauncherMode = .launch
    
    private init() {}
    
    func updateMode(_ mode: LauncherMode) {
        currentMode = mode
    }
    
    func startMonitoring() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
            let characters = event.characters
            let isNumericKey = self.isNumericShortcut(characters: characters, modifierFlags: modifierFlags)
            let shouldConsume = self.shouldConsumeEvent(keyCode: keyCode, isNumericKey: isNumericKey, for: self.currentMode)
            if shouldConsume {
                Task { @MainActor in
                    self.handleKeyPress(keyCode: keyCode, characters: characters)
                }
                return nil
            } else {
                return event
            }
        }
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            let modifierFlags = event.modifierFlags
            Task { @MainActor in
                self.handleFlagsChange(flags: modifierFlags)
            }
            return event
        }
    }
    
    private func isNumericShortcut(characters: String?, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
              let chars = characters,
              let number = Int(chars),
              (0...9).contains(number) else {
            return false
        }
        return true
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

// MARK: - 键盘事件处理逻辑（从 LauncherFacade.swift 移动过来）
extension KeyboardEventHandler {
    @MainActor
    func handleKeyPress(keyCode: UInt16, characters: String?) {
        let viewModel = LauncherViewModel.shared
        switch keyCode {
        case 126: // Up Arrow
            if viewModel.showCommandSuggestions {
                viewModel.moveCommandSuggestionUp()
            } else {
                viewModel.moveSelectionUp()
            }
        case 125: // Down Arrow
            if viewModel.showCommandSuggestions {
                viewModel.moveCommandSuggestionDown()
            } else {
                viewModel.moveSelectionDown()
            }
        case 36, 76: // Enter, Numpad Enter
            handleEnterKey()
        case 49: // Space
            handleSpaceKey()
        case 53: // Escape
            NotificationCenter.default.post(name: .hideWindowWithoutActivating, object: nil)
        default:
            handleNumericShortcut(characters: characters)
        }
    }

    @MainActor
    func handleEnterKey() {
        let viewModel = LauncherViewModel.shared
        if viewModel.showCommandSuggestions {
            if !viewModel.commandSuggestions.isEmpty &&
               viewModel.selectedIndex >= 0 &&
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                return
            }
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        guard viewModel.executeSelectedAction() else { return }
        switch viewModel.mode {
        case .kill:
            break
        case .file:
            if viewModel.selectedIndex >= 0,
               viewModel.selectedIndex < viewModel.displayableItems.count,
               let fileItem = viewModel.displayableItems[viewModel.selectedIndex] as? FileItem,
               !fileItem.isDirectory {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        case .plugin:
            break
        default:
            NotificationCenter.default.post(name: .hideWindow, object: nil)
        }
    }

    @MainActor
    func handleSpaceKey() {
        let viewModel = LauncherViewModel.shared
        if viewModel.showCommandSuggestions {
            if !viewModel.commandSuggestions.isEmpty &&
               viewModel.selectedIndex >= 0 &&
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                return
            }
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        if viewModel.mode == .file,
           viewModel.selectedIndex >= 0,
           viewModel.selectedIndex < viewModel.displayableItems.count,
           let fileItem = viewModel.displayableItems[viewModel.selectedIndex] as? FileItem {
            FileManager_LightLauncher.shared.openInFinder(fileItem.url)
        }
    }

    @MainActor
    func handleNumericShortcut(characters: String?) {
        let viewModel = LauncherViewModel.shared
        guard let chars = characters,
              let number = Int(chars),
              (1...6).contains(number) else {
            return
        }
        switch viewModel.mode {
        case .launch:
            if let controller = viewModel.controllers[.launch] as? LaunchModeController,
               controller.selectAppByNumber(number) {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        case .kill:
            // 可按需实现 kill 模式数字快捷键
            break
        case .plugin:
            break
        default:
            NotificationCenter.default.post(name: .hideWindow, object: nil)
        }
    }

    // 让决策函数变为纯函数，依赖传入的参数而不是外部 Actor 状态
    private func shouldPassThroughNumericKey(for mode: LauncherMode) -> Bool {
        return mode == .web || mode == .search || mode == .terminal || mode == .plugin || mode == .clip || mode == .keyword
    }

    private func shouldConsumeEvent(keyCode: UInt16, isNumericKey: Bool, for mode: LauncherMode) -> Bool {
        switch keyCode {
        case 126, 125, 36, 76, 53: // Up, Down, Enter, Numpad Enter, Esc
            return true
        case 49: // Space
            return mode == .file
        default:
            // 消费数字键的条件是：它是一个数字键，并且不应该被“透传”
            return isNumericKey && !self.shouldPassThroughNumericKey(for: mode)
        }
    }

    // 处理修饰键变化
    @MainActor
    func handleFlagsChange(flags: NSEvent.ModifierFlags) {
        let isCommand = flags.contains(.command)
        if isCommand {
            handleCommandKey()
        }
    }

    // 只处理 command 键按下事件
    @MainActor
    func handleCommandKey() {
        let viewModel = LauncherViewModel.shared
        if viewModel.mode == .kill {
            KillModeController.shared.forceKillEnabled.toggle()
        } else if viewModel.mode == .clip {
            ClipModeController.shared.isSnippetMode.toggle()
        } 
    }
}

