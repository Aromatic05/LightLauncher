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
        // 如果是其他模式的命令前缀，不切换到launch模式（让上层命令解析器处理）
        if text.hasPrefix("/") {
            let otherPrefixes = ["/k", "/s", "/w", "/t", "/o"]
            for otherPrefix in otherPrefixes {
                if text.hasPrefix(otherPrefix) && otherPrefix != prefix {
                    return false // 让上层处理其他模式的命令
                }
            }
        }
        
        // 如果当前模式有前缀且输入不匹配该前缀，切换回launch模式
        if !prefix.isEmpty && !text.hasPrefix(prefix) {
            return true
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
        print("🔄 MainCommandProcessor.processInput: '\(text)'")
        
        // 首先检查是否为以"/"开头的命令
        if text.hasPrefix("/") {
            let commandPart = text.components(separatedBy: " ").first ?? text
            print("📝 检查命令: '\(commandPart)'")
            
            // 优先尝试解析内置标准命令（效率更高）
            if let command = LauncherCommand.parseCommand(from: text) {
                print("✅ 找到内置命令: \(command.trigger)")
                let processor = processors.first { $0.canHandle(command: command.trigger) }
                if let processor = processor {
                    print("🔧 使用内置命令处理器")
                    return processor.process(command: command.trigger, in: viewModel)
                }
            }
            
            // 然后检查插件命令
            print("📝 检查插件命令: '\(commandPart)'")
            if PluginManager.shared.canHandleCommand(commandPart) {
                print("✅ 找到插件处理该命令: \(commandPart)")
                // 找到插件处理器
                let pluginProcessor = processors.first { processor in
                    String(describing: type(of: processor)).contains("Plugin")
                }
                
                if let processor = pluginProcessor {
                    print("🔌 使用插件处理器处理命令")
                    return processor.process(command: commandPart, in: viewModel)
                } else {
                    print("❌ 未找到插件处理器")
                }
            } else {
                print("❌ 没有插件能处理命令: \(commandPart)")
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
        
        if text == "/" {
            return LauncherCommand.getEnabledCommands()
        }
        
        return LauncherCommand.getCommandSuggestions(for: text)
    }
}
