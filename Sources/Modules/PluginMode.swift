import Foundation
import SwiftUI

/// 插件模式控制器 - 插件系统的核心控制器
/// 负责集成所有插件组件，提供统一的插件管理接口
@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()

    // MARK: - ModeStateController 协议属性
    var displayName: String { "Plugin" }

    var iconName: String { "puzzlepiece.extension" }
    var placeholder: String {
        if let activePlugin = currentPlugin {
            return activePlugin.manifest.placeholder ?? "输入命令..."
        }
        return "输入插件命令..."
    }
    var modeDescription: String? { "使用插件扩展功能" }
    var prefix: String? { "/p" }

    // MARK: - 插件相关属性
    @Published private(set) var displayableItems: [any DisplayableItem] = []
    @Published private(set) var currentPlugin: Plugin?
    @Published private(set) var activeInstance: PluginInstance?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - 依赖组件
    private let pluginManager = PluginManager.shared
    private let pluginExecutor = PluginExecutor.shared
    private let configManager = PluginConfigManager.shared
    private let permissionManager = PluginPermissionManager.shared

    // MARK: - 内部状态
    private var commandMap: [String: String] = [:]
    private var lastInput: String = ""

    private init() {
        setupPluginSystem()
    }

    // MARK: - ModeStateController 协议实现

    func shouldActivate(for text: String) -> Bool {
        // 检查是否以插件前缀开头
        if text.hasPrefix("/p ") || text == "/p" {
            return true
        }

        // 检查是否是已知的插件命令
        let command = text.components(separatedBy: " ").first ?? text
        return commandMap.keys.contains(command)
    }

    func enterMode(with text: String) {
        isLoading = true
        errorMessage = nil

        Task {
            // 确保插件已加载
            if pluginManager.getLoadedPlugins().isEmpty {
                await pluginManager.loadAllPlugins()
            }

            // 重建命令映射
            rebuildCommandMap()

            // 处理输入
            handleInput(text)

            isLoading = false
        }
    }

    func handleInput(_ text: String) {
        lastInput = text

        Task {
            await processInput(text)
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < displayableItems.count else { return false }

        if let pluginItem = displayableItems[index] as? PluginItem,
            let action = pluginItem.action,
            let instance = activeInstance
        {

            let success = instance.executeAction(action)

            // 检查是否应该隐藏窗口
            if success && (currentPlugin?.manifest.shouldHideWindowAfterAction == true) {
                return true
            }

            return success
        }

        return false
    }

    func shouldExit(for text: String) -> Bool {
        // 如果输入为空或不匹配任何插件命令，退出插件模式
        if text.isEmpty {
            return true
        }

        let command = text.components(separatedBy: " ").first ?? text
        return !commandMap.keys.contains(command) && !text.hasPrefix("/p")
    }

    func cleanup() {
        currentPlugin = nil
        activeInstance = nil
        displayableItems.removeAll()
        errorMessage = nil
        lastInput = ""
    }

    func makeContentView() -> AnyView {
        return AnyView(PluginModeView(viewModel: LauncherViewModel.shared))
    }

    static func getHelpText() -> [String] {
        let pluginManager = PluginManager.shared
        let plugins = pluginManager.getEnabledPlugins()

        var helpTexts = ["插件模式帮助:"]

        if plugins.isEmpty {
            helpTexts.append("- 当前没有可用的插件")
        } else {
            for plugin in plugins {
                helpTexts.append("- \(plugin.command): \(plugin.description)")

                if let help = plugin.manifest.help {
                    for helpLine in help {
                        helpTexts.append("  \(helpLine)")
                    }
                }
            }
        }

        return helpTexts
    }

    // MARK: - 私有方法

    private func setupPluginSystem() {
        Task {
            await pluginManager.loadAllPlugins()
            rebuildCommandMap()
        }
    }

    private func rebuildCommandMap() {
        commandMap.removeAll()

        for plugin in pluginManager.getEnabledPlugins() {
            commandMap[plugin.command] = plugin.name
        }
    }

    private func processInput(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 处理插件前缀
        var actualInput = trimmedText
        if trimmedText.hasPrefix("/p ") {
            actualInput = String(trimmedText.dropFirst(3))
        } else if trimmedText == "/p" {
            actualInput = ""
        }

        // 解析命令
        let components = actualInput.components(separatedBy: " ")
        let command = components.first ?? ""
        let args = components.count > 1 ? Array(components.dropFirst()).joined(separator: " ") : ""

        // 如果没有命令，显示可用插件列表
        if command.isEmpty {
            await showAvailablePlugins()
            return
        }

        // 查找对应的插件
        guard let pluginName = commandMap[command],
            let plugin = pluginManager.getPlugin(named: pluginName)
        else {
            await showPluginNotFound(command: command)
            return
        }

        // 切换到对应插件
        await switchToPlugin(plugin, input: args.isEmpty ? actualInput : args)
    }

    private func showAvailablePlugins() async {
        let plugins = pluginManager.getEnabledPlugins()

        let items = plugins.map { plugin in
            PluginItem(
                title: plugin.manifest.displayName,
                subtitle: "\(plugin.command) - \(plugin.description)",
                iconName: plugin.manifest.iconName ?? "puzzlepiece.extension",
                action: "select_plugin:\(plugin.name)"
            )
        }

        displayableItems = items
        currentPlugin = nil
        activeInstance = nil
    }

    private func showPluginNotFound(command: String) async {
        let item = PluginItem(
            title: "未找到插件命令: \(command)",
            subtitle: "输入 /p 查看可用插件",
            iconName: "questionmark.circle",
            action: nil
        )

        displayableItems = [item]
        currentPlugin = nil
        activeInstance = nil
    }

    private func switchToPlugin(_ plugin: Plugin, input: String) async {
        // 如果已经是当前插件，直接处理输入
        if currentPlugin?.name == plugin.name,
            let instance = activeInstance
        {
            instance.handleInput(input)
            updateDisplayableItems(from: instance)
            return
        }

        // 切换到新插件
        currentPlugin = plugin

        // 获取或创建插件实例
        if let existingInstance = pluginExecutor.getInstance(for: plugin.name) {
            activeInstance = existingInstance
        } else {
            activeInstance = pluginExecutor.createInstance(for: plugin)
        }

        guard let instance = activeInstance else {
            errorMessage = "无法创建插件实例: \(plugin.name)"
            return
        }

        // 处理输入
        instance.handleInput(input)
        updateDisplayableItems(from: instance)
    }

    func updateDisplayableItems(from instance: PluginInstance) {
        displayableItems = instance.currentItems
    }

    // MARK: - 公共方法

    /// 重新加载所有插件
    func reloadPlugins() async {
        isLoading = true

        await pluginManager.reloadPlugins()
        rebuildCommandMap()

        // 清理当前状态
        cleanup()

        isLoading = false
    }

    /// 获取当前插件是否应该隐藏窗口
    func getPluginShouldHideWindowAfterAction() -> Bool {
        return currentPlugin?.manifest.shouldHideWindowAfterAction ?? true
    }

    /// 获取插件统计信息
    func getStatistics() -> [String: Any] {
        return [
            "totalPlugins": pluginManager.getLoadedPlugins().count,
            "enabledPlugins": pluginManager.getEnabledPlugins().count,
            "activeInstances": pluginExecutor.getAllInstances().count,
            "currentPlugin": currentPlugin?.name ?? "none",
            "commandMap": commandMap,
        ]
    }
}

// MARK: - 插件管理扩展
extension PluginModeController {
    /// 启用插件
    func enablePlugin(_ pluginName: String) {
        pluginManager.enablePlugin(pluginName)
        rebuildCommandMap()
    }

    /// 禁用插件
    func disablePlugin(_ pluginName: String) {
        pluginManager.disablePlugin(pluginName)
        pluginExecutor.destroyInstance(for: pluginName)
        rebuildCommandMap()

        // 如果当前插件被禁用，清理状态
        if currentPlugin?.name == pluginName {
            cleanup()
        }
    }

    /// 重启插件
    func restartPlugin(_ pluginName: String) {
        if let plugin = pluginManager.getPlugin(named: pluginName) {
            pluginExecutor.destroyInstance(for: pluginName)
            _ = pluginExecutor.createInstance(for: plugin)

            // 如果是当前插件，重新激活
            if currentPlugin?.name == pluginName {
                Task {
                    await switchToPlugin(plugin, input: lastInput)
                }
            }
        }
    }
}
