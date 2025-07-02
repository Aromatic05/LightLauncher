import Foundation
import os

// MARK: - 插件命令处理器
@MainActor
class PluginCommandProcessor: CommandProcessor {
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "JSCommandProcessor")
    private let pluginManager = PluginManager.shared
    
    // 当前激活的插件
    private var activePlugin: Plugin?
    private var currentResults: [PluginItem] = []
    
    // MARK: - CommandProcessor 协议实现
    
    func canHandle(command: String) -> Bool {
        // 检查是否有插件注册了该命令
        let canHandle = pluginManager.canHandleCommand(command)
        print("🔌 PluginCommandProcessor.canHandle(\(command)) = \(canHandle)")
        if canHandle {
            logger.debug("Plugin can handle command: \(command)")
        }
        return canHandle
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        print("🔌 PluginCommandProcessor.process(\(command))")
        logger.info("Processing plugin command: \(command)")
        
        // 获取对应的插件
        guard let plugin = pluginManager.activatePlugin(command: command) else {
            print("❌ No plugin found for command: \(command)")
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
        
        // 切换到插件模式
        // 注意：这里需要扩展 LauncherViewModel 支持插件模式
        // 目前先返回 true 表示处理成功
        logger.info("Activated plugin: \(plugin.name)")
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        guard let plugin = activePlugin else {
            logger.warning("No active plugin for search")
            return
        }
        
        logger.debug("Handling search in plugin \(plugin.name): \(text)")
        
        // TODO: 在后续阶段实现 JavaScript 执行
        // 目前提供模拟结果
        Task {
            await simulatePluginSearch(query: text, plugin: plugin)
        }
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard let plugin = activePlugin else {
            logger.warning("No active plugin for action execution")
            return false
        }
        
        guard index >= 0 && index < currentResults.count else {
            logger.error("Invalid action index: \(index)")
            return false
        }
        
        let item = currentResults[index]
        logger.info("Executing action for item: \(item.title) in plugin: \(plugin.name)")
        
        // TODO: 在后续阶段实现 JavaScript 动作执行
        // 目前返回 true 表示成功
        return true
    }
    
    // MARK: - 公开方法
    
    /// 获取当前结果
    func getCurrentResults() -> [PluginItem] {
        return currentResults
    }
    
    /// 清除当前插件状态
    func clearState() {
        activePlugin = nil
        currentResults = []
        logger.debug("Cleared plugin state")
    }
    
    /// 获取当前激活的插件
    func getActivePlugin() -> Plugin? {
        return activePlugin
    }
    
    // MARK: - 私有方法
    
    private func simulatePluginSearch(query: String, plugin: Plugin) async {
        // 模拟异步搜索结果
        let mockResults = createMockResults(for: query, plugin: plugin)
        
        await MainActor.run {
            self.currentResults = mockResults
            self.logger.debug("Updated results for plugin \(plugin.name): \(mockResults.count) items")
        }
    }
    
    private func createMockResults(for query: String, plugin: Plugin) -> [PluginItem] {
        // 创建模拟结果用于测试
        if query.isEmpty {
            return [
                PluginItem(
                    title: "Welcome to \(plugin.name)",
                    subtitle: "Start typing to search...",
                    icon: "magnifyingglass"
                )
            ]
        }
        
        return [
            PluginItem(
                title: "Search: \(query)",
                subtitle: "Result from \(plugin.name)",
                icon: "doc.text"
            ),
            PluginItem(
                title: "Action: \(query)",
                subtitle: "Perform action with \(plugin.name)",
                icon: "play.circle"
            )
        ]
    }
}

// MARK: - 插件模式处理器
@MainActor
class PluginModeHandler: ModeHandler {
    let prefix: String
    let mode: LauncherMode = .plugin // 需要在 LauncherModes.swift 中添加
    
    private let pluginProcessor = PluginCommandProcessor()
    
    init(prefix: String) {
        self.prefix = prefix
    }
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        return false // 插件模式不自动切换回启动模式
    }
    
    func extractSearchText(from text: String) -> String {
        // 移除命令前缀，返回搜索文本
        let cleanText = text.hasPrefix(prefix) ? String(text.dropFirst(prefix.count)) : text
        return cleanText.trimmingCharacters(in: .whitespaces)
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        let searchText = extractSearchText(from: text)
        pluginProcessor.handleSearch(text: searchText, in: viewModel)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return pluginProcessor.executeAction(at: index, in: viewModel)
    }
    
    // MARK: - 插件特定方法
    
    func getResults() -> [PluginItem] {
        return pluginProcessor.getCurrentResults()
    }
    
    func getActivePlugin() -> Plugin? {
        return pluginProcessor.getActivePlugin()
    }
    
    func clearState() {
        pluginProcessor.clearState()
    }
}
