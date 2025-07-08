import Foundation
import JavaScriptCore
import os

/// 插件执行器，负责插件 JS 执行、ViewModel 注入、动作调用、资源清理等
@MainActor
class PluginExecutor {
    static let shared = PluginExecutor()
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "PluginExecutor")
    private init() {}

    /// 为指定插件注入 LauncherViewModel 引用
    func injectViewModel(_ viewModel: LauncherViewModel, for command: String) {
        guard let plugin = PluginManager.shared.plugins[command] else {
            logger.warning("Plugin not found for command: \(command)")
            return
        }
        plugin.apiManager?.viewModel = viewModel
        logger.debug("ViewModel injected for plugin: \(plugin.name)")
    }

    /// 执行插件搜索
    func executePluginSearch(command: String, query: String) {
        guard let plugin = PluginManager.shared.plugins[command],
              let apiManager = plugin.apiManager else {
            logger.warning("Plugin or API manager not found for command: \(command)")
            return
        }
        apiManager.invokeSearchCallback(with: query)
    }

    /// 执行插件搜索（推荐：直接传 Plugin 实例，避免重复查找/初始化）
    func executePluginSearch(plugin: Plugin, query: String) {
        guard let apiManager = plugin.apiManager else {
            logger.warning("API manager not found for plugin: \(plugin.name)")
            return
        }
        apiManager.invokeSearchCallback(with: query)
    }

    /// 执行插件动作
    func executePluginAction(command: String, action: String) -> Bool {
        guard let plugin = PluginManager.shared.plugins[command],
              let apiManager = plugin.apiManager else {
            logger.warning("Plugin or API manager not found for command: \(command)")
            return false
        }
        return apiManager.invokeActionHandler(with: action)
    }

    /// 获取插件的窗口隐藏设置
    func getPluginShouldHideWindowAfterAction(command: String) -> Bool {
        guard let plugin = PluginManager.shared.plugins[command] else {
            return true
        }
        return plugin.shouldHideWindowAfterAction
    }

    /// 清理插件资源
    func cleanupPlugin(command: String) async {
        await PluginManager.shared.resetPlugin(for: command)
    }

    /// 清理所有插件资源
    func cleanupAllPlugins() async {
        for command in PluginManager.shared.plugins.keys {
            await cleanupPlugin(command: command)
        }
        logger.info("Cleaned up all plugins")
    }
}
