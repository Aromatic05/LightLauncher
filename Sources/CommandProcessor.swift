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
        // 如果是以"/"开头的命令，需要更精确的匹配
        if text.hasPrefix("/") {
            // 获取输入的命令部分（空格前的部分）
            let inputCommand = text.components(separatedBy: " ").first ?? text
            
            // 检查是否是已知的内置命令
            let knownCommands = ["/k", "/s", "/w", "/t", "/o"]
            
            // 检查是否是插件命令（精确匹配或者是插件命令的开始）
            let pluginCommands = PluginManager.shared.getAllPlugins().map { $0.command }
            
            // 如果输入正好匹配某个内置命令或插件命令，不切换模式
            if knownCommands.contains(inputCommand) || pluginCommands.contains(inputCommand) {
                return false
            }
            
            // 如果输入可能是某个命令的前缀，也不切换模式
            // 检查是否有命令以输入的文本开头
            let allCommands = knownCommands + pluginCommands
            let hasMatchingPrefix = allCommands.contains { command in
                command.hasPrefix(inputCommand) && command != inputCommand
            }
            
            if hasMatchingPrefix {
                return false
            }
            
            // 如果当前模式有自己的前缀，且输入不匹配该前缀，切换回launch模式
            if !prefix.isEmpty && inputCommand != prefix && !inputCommand.hasPrefix(prefix + " ") {
                return true
            }
        } else {
            // 非命令输入：如果当前模式有前缀且输入不匹配该前缀，切换回launch模式
            if !prefix.isEmpty && !text.hasPrefix(prefix) {
                return true
            }
        }
        
        return false
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

// MARK: - 命令处理器注册协议
@MainActor
protocol CommandProcessorRegistrar {
    static func registerProcessor() -> CommandProcessor
    static func registerModeHandler() -> ModeHandler?
}

// MARK: - 主命令处理器
@MainActor
class MainCommandProcessor: ObservableObject {
    private var processors: [CommandProcessor] = []
    private var modeHandlers: [LauncherMode: ModeHandler] = [:]
    
    init() {
        registerProcessors()
    }
    
    private func registerProcessors() {
        // 注册所有命令处理器和模式处理器
        // 这里使用延迟加载，避免循环依赖
    }
    
    // 延迟注册方法，由各模式文件调用
    func registerProcessor(_ processor: CommandProcessor) {
        processors.append(processor)
    }
    
    func registerModeHandler(_ handler: ModeHandler) {
        modeHandlers[handler.mode] = handler
    }
    
    // 获取指定模式的命令处理器
    func getCommandProcessor(for mode: LauncherMode) -> CommandProcessor? {
        return processors.first { processor in
            switch mode {
            case .launch:
                return String(describing: type(of: processor)).contains("Launch")
            case .kill:
                return String(describing: type(of: processor)).contains("Kill")
            case .search:
                return String(describing: type(of: processor)).contains("Search")
            case .web:
                return String(describing: type(of: processor)).contains("Web")
            case .terminal:
                return String(describing: type(of: processor)).contains("Terminal")
            case .file:
                return String(describing: type(of: processor)).contains("File")
            case .plugin:
                return String(describing: type(of: processor)).contains("Plugin")
            }
        }
    }
    
    // 保持向后兼容
    func getProcessor(for mode: LauncherMode) -> CommandProcessor? {
        return getCommandProcessor(for: mode)
    }
    
    func processInput(_ text: String, in viewModel: LauncherViewModel) -> Bool {
        // 首先检查是否为以"/"开头的命令
        if text.hasPrefix("/") {
            let commandPart = text.components(separatedBy: " ").first ?? text
            
            // 优先尝试解析内置标准命令（效率更高）
            if let command = LauncherCommand.parseCommand(from: text) {
                let processor = processors.first { $0.canHandle(command: command.trigger) }
                if let processor = processor {
                    return processor.process(command: command.trigger, in: viewModel)
                }
            }
            
            // 然后检查插件命令
            if PluginManager.shared.canHandleCommand(commandPart) {
                // 找到插件处理器
                let pluginProcessor = processors.first { processor in
                    String(describing: type(of: processor)).contains("Plugin")
                }
                
                if let processor = pluginProcessor {
                    return processor.process(command: commandPart, in: viewModel)
                }
            }
        }
        
        // 获取当前模式的处理器
        guard let modeHandler = modeHandlers[viewModel.mode] else {
            return false
        }
        
        // 检查是否应该切换回启动模式
        if modeHandler.shouldSwitchToLaunchMode(for: text) {
            // 切换到启动模式，但不自动清空searchText
            viewModel.switchToLaunchMode()
            // 如果不是以"/"开头的前缀，立即搜索
            if !text.hasPrefix("/") && !text.isEmpty {
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
        return CommandSuggestionManager.getSuggestions(for: text)
    }
    
    func shouldShowCommandSuggestions() -> Bool {
        return SettingsManager.shared.showCommandSuggestions
    }
}

// MARK: - 全局处理器注册机制
@MainActor
class ProcessorRegistry {
    static let shared = ProcessorRegistry()
    private var mainProcessor: MainCommandProcessor?
    
    private init() {}
    
    func setMainProcessor(_ processor: MainCommandProcessor) {
        self.mainProcessor = processor
    }
    
    func registerProcessor(_ processor: CommandProcessor) {
        mainProcessor?.registerProcessor(processor)
    }
    
    func registerModeHandler(_ handler: ModeHandler) {
        mainProcessor?.registerModeHandler(handler)
    }
}

// MARK: - 命令建议提供器协议
protocol CommandSuggestionProvider {
    static func getHelpText() -> [String]
}

// MARK: - 通用命令建议管理器
@MainActor
struct CommandSuggestionManager {
    static func getSuggestions(for text: String) -> [LauncherCommand] {
        if text.isEmpty {
            return []
        }
        
        // 统一使用 getCommandSuggestions，这个方法已经包含了插件命令
        return LauncherCommand.getCommandSuggestions(for: text)
    }
}
