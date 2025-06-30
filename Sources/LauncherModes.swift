import Foundation
import AppKit

// MARK: - 启动器模式枚举
enum LauncherMode: String, CaseIterable {
    case launch = "launch"    // 启动模式 (默认)
    case kill = "kill"        // 关闭应用模式 (/k)
    
    var displayName: String {
        switch self {
        case .launch:
            return "Light Launcher"
        case .kill:
            return "Kill Mode"
        }
    }
    
    var iconName: String {
        switch self {
        case .launch:
            return "magnifyingglass"
        case .kill:
            return "xmark.circle"
        }
    }
    
    var placeholder: String {
        switch self {
        case .launch:
            return "Search applications..."
        case .kill:
            return "Search running apps to close..."
        }
    }
}

// MARK: - 命令定义
struct LauncherCommand {
    let trigger: String          // 触发字符串，如 "/k"
    let mode: LauncherMode      // 对应的模式
    let description: String     // 命令描述
    
    static let allCommands: [LauncherCommand] = [
        LauncherCommand(
            trigger: "/k",
            mode: .kill,
            description: "Enter kill mode to close running applications"
        )
    ]
    
    static func parseCommand(from text: String) -> LauncherCommand? {
        return allCommands.first { $0.trigger == text }
    }
}

// MARK: - 应用信息结构
struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
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
