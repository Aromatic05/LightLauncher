import Foundation
import AppKit

// MARK: - 基础命令协议
@MainActor
protocol LauncherCommandHandler {
    var trigger: String { get }
    var description: String { get }
    var mode: LauncherMode { get }
    
    func execute(in viewModel: LauncherViewModel) -> Bool
    func handleInput(_ text: String, in viewModel: LauncherViewModel)
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool
}

// MARK: - 默认启动命令
@MainActor
struct LaunchCommand: LauncherCommandHandler {
    let trigger = ""
    let description = "Launch applications"
    let mode = LauncherMode.launch
    
    func execute(in viewModel: LauncherViewModel) -> Bool {
        viewModel.switchToLaunchMode()
        return true
    }
    
    func handleInput(_ text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 启动命令处理器
@MainActor
class LaunchCommandProcessor: CommandProcessor, ModeHandler {
    var prefix: String { "" }
    var mode: LauncherMode { .launch }
    
    func canHandle(command: String) -> Bool {
        return command.isEmpty || !command.hasPrefix("/")
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 启动模式是默认模式，不需要特殊处理
        return false
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 启动模式处理器
@MainActor
class LaunchModeHandler: ModeHandler {
    let prefix = ""
    let mode = LauncherMode.launch
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        return false // 已经在启动模式
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 启动命令建议提供器
struct LaunchCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type to search applications",
            "Press ↑↓ arrows or numbers 1-6 to select",
            "Type / to see all commands",
            "Press Esc to close"
        ]
    }
}
