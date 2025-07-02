import Foundation
import AppKit
import Combine

// MARK: - 模式处理器协议
@MainActor
protocol ModeHandler {
    var prefix: String { get }
    var mode: LauncherMode { get }
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool
    func extractSearchText(from text: String) -> String
    func handleSearch(text: String, in viewModel: LauncherViewModel)
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool
}

// MARK: - 默认模式处理器实现
@MainActor
extension ModeHandler {
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        return !text.hasPrefix(prefix)
    }
    
    func extractSearchText(from text: String) -> String {
        if text.hasPrefix(prefix + " ") {
            return String(text.dropFirst(prefix.count + 1))
        } else if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }
}

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
    private var modeHandlers: [LauncherMode: ModeHandler] = [:]
    
    init() {
        setupProcessors()
        setupModeHandlers()
    }
    
    private func setupProcessors() {
        processors = [
            LaunchCommandProcessor(),
            KillCommandProcessor(),
            SearchCommandProcessor(),
            WebCommandProcessor(),
            TerminalCommandProcessor(),
            FileCommandProcessor()
        ]
    }
    
    private func setupModeHandlers() {
        modeHandlers = [
            .launch: LaunchModeHandler(),
            .kill: KillModeHandler(),
            .search: SearchModeHandler(mainProcessor: self),
            .web: WebModeHandler(mainProcessor: self),
            .terminal: TerminalModeHandler(mainProcessor: self),
            .file: FileModeHandler(mainProcessor: self)
        ]
    }
    
    // 为模式处理器提供访问CommandProcessor的方法
    func getProcessor(for mode: LauncherMode) -> CommandProcessor? {
        switch mode {
        case .launch:
            return processors.first { $0 is LaunchCommandProcessor }
        case .kill:
            return processors.first { $0 is KillCommandProcessor }
        case .search:
            return processors.first { $0 is SearchCommandProcessor }
        case .web:
            return processors.first { $0 is WebCommandProcessor }
        case .terminal:
            return processors.first { $0 is TerminalCommandProcessor }
        case .file:
            return processors.first { $0 is FileCommandProcessor }
        }
    }
    
    func processInput(_ text: String, in viewModel: LauncherViewModel) -> Bool {
        // 在启动模式下检查命令
        if viewModel.mode == .launch {
            if let command = LauncherCommand.parseCommand(from: text) {
                let processor = processors.first { $0.canHandle(command: command.trigger) }
                return processor?.process(command: command.trigger, in: viewModel) ?? false
            }
        }
        
        // 获取当前模式的处理器
        guard let modeHandler = modeHandlers[viewModel.mode] else {
            return false
        }
        
        // 检查是否应该切换回启动模式
        if modeHandler.shouldSwitchToLaunchMode(for: text) {
            viewModel.switchToLaunchMode()
            if !text.isEmpty {
                viewModel.filterApps(searchText: text)
            }
            return true
        }
        
        // 提取搜索文本并处理
        let searchText = modeHandler.extractSearchText(from: text)
        modeHandler.handleSearch(text: searchText, in: viewModel)
        return false
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        if let modeHandler = modeHandlers[viewModel.mode] {
            return modeHandler.executeAction(at: index, in: viewModel)
        }
        return false
    }
    
    func getCommandSuggestions(for text: String) -> [LauncherCommand] {
        return LauncherCommand.getCommandSuggestions(for: text)
    }
    
    func shouldShowCommandSuggestions() -> Bool {
        return SettingsManager.shared.showCommandSuggestions
    }
    
    private func getCurrentProcessor(for mode: LauncherMode) -> CommandProcessor? {
        switch mode {
        case .launch:
            return processors.first { $0 is LaunchCommandProcessor }
        case .kill:
            return processors.first { $0 is KillCommandProcessor }
        case .search:
            return processors.first { $0 is SearchCommandProcessor }
        case .web:
            return processors.first { $0 is WebCommandProcessor }
        case .terminal:
            return processors.first { $0 is TerminalCommandProcessor }
        case .file:
            return processors.first { $0 is FileCommandProcessor }
        }
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

// MARK: - 关闭应用命令处理器
@MainActor
class KillCommandProcessor: CommandProcessor, ModeHandler {
    var prefix: String { "/k" }
    var mode: LauncherMode { .kill }
    
    func canHandle(command: String) -> Bool {
        return command == "/k"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        if command == "/k" {
            viewModel.switchToKillMode()
            // 设置搜索文本为 "/k"，保持前缀显示
            viewModel.searchText = "/k"
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

// MARK: - 具体模式处理器实现

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
                "Type / to see all commands",
                "Press Esc to close"
            ]
        case .kill:
            return [
                "Type after /k to search running apps",
                "Press ↑↓ arrows or numbers 1-6 to select", 
                "Delete /k prefix to return to launch mode",
                "Press Esc to close"
            ]
        case .search:
            return [
                "Type after /s to search the web",
                "Press Enter to execute search",
                "Delete /s prefix to return to launch mode",
                "Press Esc to close"
            ]
        case .web:
            return [
                "Type after /w to open website or URL",
                "Press Enter to open in browser",
                "Delete /w prefix to return to launch mode", 
                "Press Esc to close"
            ]
        case .terminal:
            return [
                "Type after /t to execute terminal command",
                "Press Enter to run in Terminal",
                "Delete /t prefix to return to launch mode",
                "Press Esc to close"
            ]
        case .file:
            return [
                "Browse files and folders starting from home directory",
                "Press Enter to open files or navigate folders",
                "Press Space to open current folder in Finder",
                "Delete /o prefix to return to launch mode",
                "Press Esc to close"
            ]
        }
    }
}
