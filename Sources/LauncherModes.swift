import Foundation
import AppKit

// MARK: - 启动器模式枚举
enum LauncherMode: String, CaseIterable {
    case launch = "launch"    // 启动模式 (默认)
    case kill = "kill"        // 关闭应用模式 (/k)
    case search = "search"    // 网页搜索模式 (/s)
    case web = "web"          // 网页打开模式 (/w)
    case terminal = "terminal" // 终端执行模式 (/t)
    
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

// MARK: - 应用信息结构
struct AppInfo: Identifiable, Hashable {
    let name: String
    let url: URL
    
    // 使用 URL 路径作为唯一标识符，避免重复应用
    var id: String {
        url.path
    }
    
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url.path == rhs.url.path
    }
}

// MARK: - 运行中应用信息结构
struct RunningAppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isHidden: Bool
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == processIdentifier }) {
            return app.icon
        }
        return nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 应用匹配结果结构
struct AppMatch {
    let app: AppInfo
    let score: Double
    let matchType: MatchType
    
    enum MatchType {
        case exactStart      // 完全匹配开头
        case wordStart       // 单词开头匹配
        case subsequence     // 子序列匹配
        case fuzzy          // 模糊匹配
        case contains       // 包含匹配
    }
}

// MARK: - 模式数据协议
protocol ModeData {
    var count: Int { get }
    func item(at index: Int) -> Any?
}

// MARK: - 启动模式数据
struct LaunchModeData: ModeData {
    let apps: [AppInfo]
    
    var count: Int { apps.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < apps.count else { return nil }
        return apps[index]
    }
}

// MARK: - 关闭模式数据
struct KillModeData: ModeData {
    let runningApps: [RunningAppInfo]
    
    var count: Int { runningApps.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < runningApps.count else { return nil }
        return runningApps[index]
    }
}
