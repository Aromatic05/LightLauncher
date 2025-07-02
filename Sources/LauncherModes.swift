import Foundation
import AppKit

// MARK: - 启动器模式枚举
enum LauncherMode: String, CaseIterable {
    case launch = "launch"    // 启动模式 (默认)
    case kill = "kill"        // 关闭应用模式 (/k)
    case search = "search"    // 网页搜索模式 (/s)
    case web = "web"          // 网页打开模式 (/w)
    case terminal = "terminal" // 终端执行模式 (/t)
    case file = "file"        // 文件管理器模式 (/o)
    
    var displayName: String {
        switch self {
        case .launch:
            return "Light Launcher"
        case .kill:
            return "Kill Mode"
        case .search:
            return "Web Search"
        case .web:
            return "Web Open"
        case .terminal:
            return "Terminal"
        case .file:
            return "File Browser"
        }
    }
    
    var iconName: String {
        switch self {
        case .launch:
            return "magnifyingglass"
        case .kill:
            return "xmark.circle"
        case .search:
            return "globe"
        case .web:
            return "safari"
        case .terminal:
            return "terminal"
        case .file:
            return "folder"
        }
    }
    
    var placeholder: String {
        switch self {
        case .launch:
            return "Search applications..."
        case .kill:
            return "Search running apps to close..."
        case .search:
            return "Enter search query..."
        case .web:
            return "Enter URL or website name..."
        case .terminal:
            return "Enter terminal command..."
        case .file:
            return "Browse files and folders..."
        }
    }
}

// MARK: - 命令定义
struct LauncherCommand {
    let trigger: String          // 触发字符串，如 "/k"
    let mode: LauncherMode      // 对应的模式
    let description: String     // 命令描述
    let isEnabled: Bool         // 是否启用
    
    static let allCommands: [LauncherCommand] = [
        LauncherCommand(
            trigger: "/k",
            mode: .kill,
            description: "Enter kill mode to close running applications",
            isEnabled: true
        ),
        LauncherCommand(
            trigger: "/s",
            mode: .search,
            description: "Search the web using your default search engine",
            isEnabled: true
        ),
        LauncherCommand(
            trigger: "/w",
            mode: .web,
            description: "Open a website or URL in your default browser",
            isEnabled: true
        ),
        LauncherCommand(
            trigger: "/t",
            mode: .terminal,
            description: "Execute commands in Terminal",
            isEnabled: true
        ),
        LauncherCommand(
            trigger: "/o",
            mode: .file,
            description: "Browse files and folders starting from home directory",
            isEnabled: true
        )
    ]
    
    @MainActor
    static func parseCommand(from text: String) -> LauncherCommand? {
        return getEnabledCommands().first { $0.trigger == text }
    }
    
    @MainActor
    static func getEnabledCommands() -> [LauncherCommand] {
        let settings = SettingsManager.shared
        return allCommands.filter { command in
            switch command.mode {
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
            }
        }
    }
    
    @MainActor
    static func getCommandSuggestions(for text: String) -> [LauncherCommand] {
        let enabledCommands = getEnabledCommands()
        
        if text == "/" {
            return enabledCommands
        }
        
        return enabledCommands.filter { command in
            command.trigger.hasPrefix(text)
        }
    }
}

// MARK: - 模式数据协议
protocol ModeData {
    var count: Int { get }
    func item(at index: Int) -> Any?
}
