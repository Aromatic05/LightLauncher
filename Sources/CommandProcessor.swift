import Foundation
import AppKit
import Combine

// MARK: - 命令处理器协议
@MainActor
protocol CommandProcessor {
    func canHandle(command: String) -> Bool
    func process(command: String, in viewModel: LauncherViewModel) -> Bool
    func handleSearch(text: String, in viewModel: LauncherViewModel)
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool
}

// MARK: - 主命令处理器
@MainActor
class MainCommandProcessor: ObservableObject {
    private var processors: [CommandProcessor] = []
    
    init() {
        setupProcessors()
    }
    
    private func setupProcessors() {
        processors = [
            LaunchCommandProcessor(),
            KillCommandProcessor()
        ]
    }
    
    func processInput(_ text: String, in viewModel: LauncherViewModel) -> Bool {
        // 检查是否是命令
        if let command = LauncherCommand.parseCommand(from: text) {
            let processor = processors.first { $0.canHandle(command: command.trigger) }
            return processor?.process(command: command.trigger, in: viewModel) ?? false
        }
        
        // 否则处理为搜索
        let currentProcessor = getCurrentProcessor(for: viewModel.mode)
        currentProcessor?.handleSearch(text: text, in: viewModel)
        return false
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        let processor = getCurrentProcessor(for: viewModel.mode)
        return processor?.executeAction(at: index, in: viewModel) ?? false
    }
    
    private func getCurrentProcessor(for mode: LauncherMode) -> CommandProcessor? {
        switch mode {
        case .launch:
            return processors.first { $0 is LaunchCommandProcessor }
        case .kill:
            return processors.first { $0 is KillCommandProcessor }
        }
    }
}

// MARK: - 启动命令处理器
@MainActor
class LaunchCommandProcessor: CommandProcessor {
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

// MARK: - 关闭应用命令处理器
@MainActor
class KillCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/k"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        if command == "/k" {
            viewModel.switchToKillMode()
            return true
        }
        return false
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterRunningApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.killSelectedApp()
    }
}

// MARK: - 命令建议提供器
struct CommandSuggestionProvider {
    static func getSuggestions(for text: String) -> [LauncherCommand] {
        if text.isEmpty {
            return []
        }
        
        if text == "/" {
            return LauncherCommand.allCommands
        }
        
        return LauncherCommand.allCommands.filter { command in
            command.trigger.hasPrefix(text)
        }
    }
    
    static func getHelpText(for mode: LauncherMode) -> [String] {
        switch mode {
        case .launch:
            return [
                "Type to search applications",
                "Press ↑↓ arrows or numbers 1-6 to select",
                "Type /k to enter kill mode",
                "Press Esc to close"
            ]
        case .kill:
            return [
                "Search for running apps to close",
                "Press ↑↓ arrows or numbers 1-6 to select", 
                "Clear search to return to launch mode",
                "Press Esc to close"
            ]
        }
    }
}
