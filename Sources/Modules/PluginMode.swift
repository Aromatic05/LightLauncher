import Foundation
import SwiftUI

/// 插件模式控制器 - 插件系统的核心控制器
/// 负责集成所有插件组件，提供统一的插件管理接口
import SwiftUI

@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()

    // MARK: - ModeStateController Protocol Implementation

    // 1. 身份与元数据
    let mode: LauncherMode = .plugin
    let prefix: String? = "/p"
    let displayName: String = "Plugins"
    let iconName: String = "puzzlepiece.extension"
    var placeholder: String {
        currentPlugin?.manifest.placeholder ?? "Enter plugin command..."
    }
    var modeDescription: String? = "Extend functionality with plugins"

    @Published private(set) var displayableItems: [any DisplayableItem] = []

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        // 记录最后一次输入，用于插件重启
        self.lastInput = arguments
        Task {
            await processPluginInput(arguments)
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < displayableItems.count,
              let pluginItem = displayableItems[index] as? PluginItem,
              let action = pluginItem.action,
              let instance = activeInstance else {
            return false
        }
        return instance.executeAction(action)
    }

    // 3. 生命周期与UI
    func cleanup() {
        currentPlugin = nil
        activeInstance = nil
        displayableItems = []
        errorMessage = nil
        lastInput = "" // 重置最后一次输入
    }

    func makeContentView() -> AnyView {
        return AnyView(PluginModeView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        let plugins = pluginManager.getEnabledPlugins()
        var helpTexts = ["Available Plugins:"]
        if plugins.isEmpty {
            helpTexts.append("- No plugins available.")
        } else {
            plugins.forEach { helpTexts.append("- \($0.command): \($0.description)") }
        }
        return helpTexts
    }
    
    // MARK: - Internal Plugin System

    @Published private(set) var currentPlugin: Plugin?
    @Published private(set) var activeInstance: PluginInstance?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let pluginManager = PluginManager.shared
    private let pluginExecutor = PluginExecutor.shared
    private var commandMap: [String: Plugin] = [:]
    private var lastInput: String = "" // 用于支持重启插件

    private init() {
        Task {
            await setupPluginSystem()
        }
    }

    private func setupPluginSystem() async {
        await pluginManager.loadAllPlugins()
        rebuildCommandMap()
    }

    private func rebuildCommandMap() {
        commandMap.removeAll()
        for plugin in pluginManager.getEnabledPlugins() {
            commandMap[plugin.command] = plugin
        }
    }

    private func processPluginInput(_ text: String) async {
        let components = text.components(separatedBy: " ")
        guard let command = components.first, !command.isEmpty else {
            showAvailablePlugins()
            return
        }
        
        let args = components.count > 1 ? Array(components.dropFirst()).joined(separator: " ") : ""
        
        guard let plugin = commandMap[command] else {
            showPluginNotFound(command: command)
            return
        }
        
        await switchToPlugin(plugin, input: args)
    }

    private func showAvailablePlugins() {
        let items = pluginManager.getEnabledPlugins().map { plugin in
            PluginItem(title: plugin.manifest.displayName, subtitle: "\(plugin.command) - \(plugin.description)", iconName: plugin.manifest.iconName ?? "puzzlepiece.extension", action: "select_plugin:\(plugin.command)")
        }
        self.displayableItems = items
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func showPluginNotFound(command: String) {
        let item = PluginItem(title: "Plugin command not found: \(command)", subtitle: "Type '/p' to see available plugins", iconName: "questionmark.circle", action: nil)
        self.displayableItems = [item]
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func switchToPlugin(_ plugin: Plugin, input: String) async {
        if currentPlugin?.name == plugin.name, let instance = activeInstance {
            instance.handleInput(input)
            updateDisplayableItems(from: instance)
            return
        }

        currentPlugin = plugin
        activeInstance = pluginExecutor.getInstance(for: plugin.name) ?? pluginExecutor.createInstance(for: plugin)
        
        guard let instance = activeInstance else {
            errorMessage = "Failed to create instance for plugin: \(plugin.name)"
            return
        }

        instance.handleInput(input)
        updateDisplayableItems(from: instance)
    }

    func updateDisplayableItems(from instance: PluginInstance) {
        displayableItems = instance.currentItems
    }
    
    // MARK: - Public Plugin Management API
    
    /// 重新加载所有插件
    func reloadPlugins() async {
        isLoading = true
        await pluginManager.reloadPlugins()
        rebuildCommandMap()
        cleanup()
        isLoading = false
    }

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

        if currentPlugin?.name == pluginName {
            cleanup()
        }
    }

    /// 重启插件
    func restartPlugin(_ pluginName: String) {
        guard let plugin = pluginManager.getPlugin(named: pluginName) else { return }
        
        pluginExecutor.destroyInstance(for: pluginName)
        
        // 如果是当前激活的插件，则用最后一次的输入重新激活它
        if currentPlugin?.name == pluginName {
            Task {
                await switchToPlugin(plugin, input: self.lastInput)
            }
        }
    }
}
