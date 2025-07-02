import Foundation
import os

// MARK: - 插件命令处理器
@MainActor
class PluginCommandProcessor: CommandProcessor, ModeHandler {
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "JSCommandProcessor")
    private let pluginManager = PluginManager.shared
    
    // 当前激活的插件
    private var activePlugin: Plugin?
    private var currentResults: [PluginItem] = []
    
    // MARK: - ModeHandler 协议实现
    var prefix: String {
        return activePlugin?.command ?? ""
    }
    
    var mode: LauncherMode {
        return .plugin
    }
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        // 如果输入不再匹配当前插件的命令，切换回启动模式
        guard let plugin = activePlugin else { return true }
        
        if text.hasPrefix("/") {
            let commandPart = text.components(separatedBy: " ").first ?? text
            // 如果输入的命令不是当前插件的命令，切换回启动模式
            return commandPart != plugin.command
        } else {
            // 如果输入不以"/"开头，说明用户想要回到启动模式
            return true
        }
    }
    
    func extractSearchText(from text: String) -> String {
        guard let plugin = activePlugin else { return text }
        
        let prefix = plugin.command
        if text.hasPrefix(prefix + " ") {
            return String(text.dropFirst(prefix.count + 1))
        } else if text == prefix {
            return ""
        }
        return text
    }
    
    // MARK: - CommandProcessor 协议实现
    
    func canHandle(command: String) -> Bool {
        // 检查是否有插件注册了该命令
        let canHandle = pluginManager.canHandleCommand(command)
        if canHandle {
            logger.debug("Plugin can handle command: \(command)")
        }
        return canHandle
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        logger.info("Processing plugin command: \(command, privacy: .public)")
        
        // 获取对应的插件
        guard let plugin = pluginManager.activatePlugin(command: command) else {
            logger.error("No plugin found for command: \(command)")
            return false
        }
        
        // 检查插件是否启用
        guard plugin.isEnabled else {
            logger.warning("Plugin is disabled: \(plugin.name)")
            return false
        }
        
        // 设置当前激活的插件
        activePlugin = plugin
        currentResults = []
        
        // 注入 ViewModel 到插件的 API 管理器
        pluginManager.injectViewModel(viewModel, for: command)
        
        // 切换到插件模式
        viewModel.switchToPluginMode(with: plugin)
        
        // 立即触发初始搜索（空查询）
        pluginManager.executePluginSearch(command: plugin.command, query: "")
        
        logger.info("Activated plugin: \(plugin.name, privacy: .public)")
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        guard let plugin = activePlugin else {
            logger.warning("No active plugin for search")
            return
        }
        
        logger.debug("Handling search in plugin \(plugin.name): \(text)")
        
        // 使用 PluginManager 执行插件搜索
        pluginManager.executePluginSearch(command: plugin.command, query: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard let plugin = activePlugin else {
            logger.warning("No active plugin for action execution")
            return false
        }
        
        // 在插件模式下，从 viewModel 获取插件结果
        let pluginItems = viewModel.pluginItems
        
        guard index >= 0 && index < pluginItems.count else {
            logger.error("Invalid action index: \(index)")
            return false
        }
        
        let item = pluginItems[index]
        logger.info("Executing action for item: \(item.title, privacy: .public) in plugin: \(plugin.name, privacy: .public)")
        
        // 如果项目有动作标识符，调用插件的动作处理器
        if let action = item.action, !action.isEmpty {
            let success = pluginManager.executePluginAction(command: plugin.command, action: action)
            logger.info("Plugin action '\(action, privacy: .public)' execution result: \(success, privacy: .public)")
            return success
        } else {
            // 如果没有动作标识符，记录警告但仍返回 true（兼容性）
            logger.warning("No action specified for item: \(item.title)")
            return true
        }
    }
    
    // MARK: - 公开方法
    
    /// 获取当前结果 - 现在从 ViewModel 的插件结果获取
    func getCurrentResults() -> [PluginItem] {
        // 现在结果通过 APIManager.display() 直接更新到 viewModel.pluginItems
        // 这里返回空数组，实际结果在 viewModel.pluginItems 中
        return []
    }
    
    /// 清除当前插件状态
    func clearState() {
        if let plugin = activePlugin {
            // 清理 PluginManager 中的插件资源
            pluginManager.cleanupPlugin(command: plugin.command)
        }
        
        activePlugin = nil
        currentResults = []
        
        logger.debug("Cleared plugin state")
    }
    
    /// 获取当前激活的插件
    func getActivePlugin() -> Plugin? {
        return activePlugin
    }
}
