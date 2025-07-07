import Foundation
import AppKit
import AppKit

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
    
    // 通过ModeStateController获取元信息，需在@MainActor上下文下访问
    @MainActor
    var displayName: String {
        LauncherViewModel.shared?.controllers[self]?.displayName ?? self.rawValue
    }
    @MainActor
    var iconName: String {
        LauncherViewModel.shared?.controllers[self]?.iconName ?? "questionmark"
    }
    @MainActor
    var placeholder: String {
        LauncherViewModel.shared?.controllers[self]?.placeholder ?? ""
    }
    @MainActor
    var description: String? {
        LauncherViewModel.shared?.controllers[self]?.modeDescription
    }
    
    var trigger: String? {
        switch self {
        case .kill: return "/k"
        case .search: return "/s"
        case .web: return "/w"
        case .terminal: return "/t"
        case .file: return "/o"
        case .clip: return "/v"
        case .launch: return ""
        case .plugin: return "" // 插件模式由具体插件的命令触发
        }
    }
    
    // 检查模式是否启用的方法
    @MainActor
    func isEnabled() -> Bool {
        let settings = SettingsManager.shared
        return settings.isModeEnabled(self.rawValue)
    }

    static func fromPrefix(_ prefix: String) -> LauncherMode? {
        switch prefix {
        case "/k": return .kill
        case "/s": return .search
        case "/w": return .web
        case "/t": return .terminal
        case "/o": return .file
        case "/v": return .clip
        case "": return .launch
        default: return nil
        }
    }
}

// MARK: - 命令定义
struct LauncherCommand {
    let trigger: String          // 触发字符串，如 "/k"
    let mode: LauncherMode      // 对应的模式
    let description: String?     // 命令描述
    let isEnabled: Bool         // 是否启用
    
    // 基于ModeStateController获取元信息
    @MainActor
    static var allCommands: [LauncherCommand] {
        guard let viewModel = LauncherViewModel.shared else { return [] }
        return LauncherMode.allCases.compactMap { mode in
            guard let controller = viewModel.controllers[mode],
                  let trigger = controller.prefix else {
                return nil
            }
            // description 可为 nil
            return LauncherCommand(
                trigger: trigger,
                mode: mode,
                description: controller.modeDescription,
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
