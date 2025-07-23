import SwiftUI
import Combine

@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()

    // MARK: - ModeStateController Protocol Implementation

    // 1. 身份与元数据
    let mode: LauncherMode = .plugin
    // 这个 prefix 只用于将 /p 命令注册为“显示插件列表”的入口
    let prefix: String? = "/p" 
    let displayName: String = "Plugins"
    let iconName: String = "puzzlepiece.extension"
    var placeholder: String {
        currentPlugin?.manifest.placeholder ?? "Enter plugin command..."
    }
    var modeDescription: String? = "Extend functionality with plugins"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet { dataDidChange.send() }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
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
        lastInput = ""
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
    private var lastInput: String = ""

    private init() {}

    private func processPluginInput(_ text: String) async {
        let components = text.components(separatedBy: " ")
        // 传入的 text 可能为空 (例如，只输入了 /p)，或者是一个完整的插件命令
        guard let command = components.first, !command.isEmpty else {
            showAvailablePlugins()
            return
        }
        
        let args = components.count > 1 ? Array(components.dropFirst()).joined(separator: " ") : ""
        
        // 使用 PluginManager 通过命令前缀查找插件
        guard let plugin = pluginManager.getPlugin(for: command) else {
            showPluginNotFound(command: command)
            return
        }
        
        await switchToPlugin(plugin, input: args)
    }

    private func showAvailablePlugins() {
        let items = pluginManager.getEnabledPlugins().map { plugin in
            PluginItem(
                title: plugin.manifest.displayName,
                subtitle: "\(plugin.command) - \(plugin.description)",
                iconName: plugin.manifest.iconName ?? "puzzlepiece.extension",
                action: "select_plugin:\(plugin.command)"
            )
        }
        self.displayableItems = items
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func showPluginNotFound(command: String) {
        let item = PluginItem(
            title: "Plugin command not found: \(command)",
            subtitle: "Type '/p' to see available plugins",
            iconName: "questionmark.circle",
            action: nil
        )
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
    
    // MARK: - Public Plugin Management API (已从 extension 移入)
    
    func reloadPlugins() async {
        isLoading = true
        await pluginManager.reloadPlugins()
        cleanup()
        isLoading = false
    }

    func enablePlugin(_ pluginName: String) {
        pluginManager.enablePlugin(pluginName)
    }

    func disablePlugin(_ pluginName: String) {
        pluginManager.disablePlugin(pluginName)
        pluginExecutor.destroyInstance(for: pluginName)
        if currentPlugin?.name == pluginName {
            cleanup()
        }
    }

    func restartPlugin(_ pluginName: String) {
        guard let plugin = pluginManager.getPlugin(named: pluginName) else { return }
        pluginExecutor.destroyInstance(for: pluginName)
        if currentPlugin?.name == pluginName {
            Task {
                await switchToPlugin(plugin, input: self.lastInput)
            }
        }
    }
}