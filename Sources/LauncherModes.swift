import Foundation
import AppKit
import AppKit

// MARK: - 模式配置数据结构
struct ModeConfiguration: Sendable {
    let displayName: String
    let iconName: String
    let placeholder: String
    let trigger: String?
    let description: String?
    
    init(displayName: String, iconName: String, placeholder: String, trigger: String? = nil, description: String? = nil) {
        self.displayName = displayName
        self.iconName = iconName
        self.placeholder = placeholder
        self.trigger = trigger
        self.description = description
    }
}

// MARK: - 启动器模式枚举
enum LauncherMode: String, CaseIterable {
    case launch = "launch"    // 启动模式 (默认)
    case kill = "kill"        // 关闭应用模式 (/k)
    case search = "search"    // 网页搜索模式 (/s)
    case web = "web"          // 网页打开模式 (/w)
    case terminal = "terminal" // 终端执行模式 (/t)
    case file = "file"        // 文件管理器模式 (/o)
    case clip = "clip"        // 剪切板历史模式 (/clip)
    case plugin = "plugin"    // 插件模式 (动态)
    
    // 配置字典 - 数据驱动方法
    private static let configurations: [LauncherMode: ModeConfiguration] = [
        .launch: ModeConfiguration(
            displayName: "Light Launcher",
            iconName: "magnifyingglass",
            placeholder: "Search applications..."
        ),
        .kill: ModeConfiguration(
            displayName: "Kill Mode",
            iconName: "xmark.circle",
            placeholder: "Search running apps to close...",
            trigger: "/k",
            description: "Enter kill mode to close running applications"
        ),
        .search: ModeConfiguration(
            displayName: "Web Search",
            iconName: "globe",
            placeholder: "Enter search query...",
            trigger: "/s",
            description: "Search the web using your default search engine"
        ),
        .web: ModeConfiguration(
            displayName: "Web Open",
            iconName: "safari",
            placeholder: "Enter URL or website name...",
            trigger: "/w",
            description: "Open a website or URL in your default browser"
        ),
        .terminal: ModeConfiguration(
            displayName: "Terminal",
            iconName: "terminal",
            placeholder: "Enter terminal command...",
            trigger: "/t",
            description: "Execute commands in Terminal"
        ),
        .file: ModeConfiguration(
            displayName: "File Browser",
            iconName: "folder",
            placeholder: "Browse files and folders...",
            trigger: "/o",
            description: "Browse files and folders starting from home directory"
        ),
        .clip: ModeConfiguration(
            displayName: "Clipboard History",
            iconName: "doc.on.clipboard",
            placeholder: "Search clipboard history...",
            trigger: "/v",
            description: "Browse and paste clipboard history (text/files)"
        ),
        .plugin: ModeConfiguration(
            displayName: "Plugin",
            iconName: "puzzlepiece",
            placeholder: "Plugin mode...",
            trigger: nil, // 插件模式由具体插件的命令触发
            description: "Plugin-powered functionality"
        )
    ]
    
    // 获取配置信息的便捷属性
    private var configuration: ModeConfiguration {
        return Self.configurations[self]!
    }
    
    var displayName: String {
        return configuration.displayName
    }
    
    var iconName: String {
        return configuration.iconName
    }
    
    var placeholder: String {
        return configuration.placeholder
    }
    
    var trigger: String? {
        return configuration.trigger
    }
    
    var description: String? {
        return configuration.description
    }
    
    // 检查模式是否启用的方法
    @MainActor
    func isEnabled() -> Bool {
        let settings = SettingsManager.shared
        switch self {
        case .launch:
            return true // 启动模式始终启用
        case .kill:
            return settings.isKillModeEnabled
        case .search:
            return settings.isSearchModeEnabled
        case .web:
            return settings.isWebModeEnabled
        case .terminal:
            return settings.isTerminalModeEnabled
        case .file:
            return settings.isFileModeEnabled
        case .clip:
            return true // 剪切板模式始终启用
        case .plugin:
            return true // 插件模式始终启用（由插件管理器控制具体插件）
        }
    }
}

// MARK: - 命令定义
struct LauncherCommand {
    let trigger: String          // 触发字符串，如 "/k"
    let mode: LauncherMode      // 对应的模式
    let description: String     // 命令描述
    let isEnabled: Bool         // 是否启用
    
    // 基于LauncherMode配置创建所有命令
    @MainActor
    static var allCommands: [LauncherCommand] {
        return LauncherMode.allCases.compactMap { mode in
            guard let trigger = mode.trigger,
                  let description = mode.description else {
                return nil
            }
            return LauncherCommand(
                trigger: trigger,
                mode: mode,
                description: description,
                isEnabled: mode.isEnabled()
            )
        }
    }
    
    @MainActor
    static func parseCommand(from text: String) -> LauncherCommand? {
        return getEnabledCommands().first { command in
            text == command.trigger || text.hasPrefix(command.trigger + " ")
        }
    }
    
    @MainActor
    static func getEnabledCommands() -> [LauncherCommand] {
        return allCommands.filter { $0.isEnabled }
    }
    
    @MainActor
    static func getCommandSuggestions(for text: String) -> [LauncherCommand] {
        // 获取内置命令
        let enabledCommands = getEnabledCommands()
        
        // 获取插件命令
        let pluginCommands = PluginManager.shared.getAllPluginCommands()
        
        // 合并所有命令
        let allCommands = enabledCommands + pluginCommands
        
        if text == "/" {
            return allCommands
        }
        
        return allCommands.filter { command in
            command.trigger.hasPrefix(text)
        }
    }
}

// MARK: - 模式数据协议
protocol ModeData {
    var count: Int { get }
    func item(at index: Int) -> Any?
}
