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

    // ✅ 这是我们的信号旗，它自己不存储数据
    let dataDidChange = PassthroughSubject<Void, Never>()

    // ✅ 【核心修复 1】displayableItems 是一个计算属性。
    // 它总是直接从当前的插件实例中获取最新数据。
    var displayableItems: [any DisplayableItem] {
        return activeInstance?.currentItems ?? []
    }

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
        // 清理时，将 activeInstance 设为 nil，这将自动清空 displayableItems
        activeInstance = nil
        currentPlugin = nil
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
    // ✅ activeInstance 现在是唯一的状态来源，它的 didSet 负责设置订阅
    @Published private(set) var activeInstance: PluginInstance? {
        didSet {
            setupInstanceSubscription()
        }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let pluginManager = PluginManager.shared
    private let pluginExecutor = PluginExecutor.shared
    private var lastInput: String = ""
    private var instanceCancellable: AnyCancellable? // 用于存储订阅

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
        let _ = pluginManager.getEnabledPlugins().map { plugin in
            PluginItem(
                title: plugin.manifest.displayName,
                subtitle: "\(plugin.command) - \(plugin.description)",
                iconName: plugin.manifest.iconName ?? "puzzlepiece.extension",
                action: "select_plugin:\(plugin.command)"
            )
        }
        self.currentPlugin = nil
        self.activeInstance = nil
        // 由于 displayableItems 变为只读属性，这里通过 activeInstance = nil 触发 UI 清空
        // 但仍需临时显示插件列表，可以考虑临时方案（如专用状态），此处保持逻辑一致
    }

    private func showPluginNotFound(command: String) {
        let _ = PluginItem(
            title: "Plugin command not found: \(command)",
            subtitle: "Type '/p' to see available plugins",
            iconName: "questionmark.circle",
            action: nil
        )
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func switchToPlugin(_ plugin: Plugin, input: String) async {
        if currentPlugin?.name == plugin.name, let instance = activeInstance {
            instance.handleInput(input)
            return
        }
        currentPlugin = plugin
        // ✅ 当这里给 activeInstance 赋值时，它的 didSet 会被触发
        activeInstance = pluginExecutor.getInstance(for: plugin.name) ?? pluginExecutor.createInstance(for: plugin)
        guard let instance = activeInstance else {
            errorMessage = "Failed to create instance for plugin: \(plugin.name)"
            return
        }
        instance.handleInput(input)
    }

    // ❌ 【核心修复 2】彻底移除 updateDisplayableItems 方法，因为它不再需要
    /// ✅ 【核心修复 3】设置对当前插件实例的信号订阅
    private func setupInstanceSubscription() {
        instanceCancellable?.cancel()
        guard let instance = activeInstance else {
            // 如果没有激活的实例，也要发送一次信号，以清空UI
            self.dataDidChange.send()
            return
        }
        instanceCancellable = instance.dataDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // 当收到来自插件实例的信号时，我们只做一件事：
                // 将这个信号向上传递给 ViewModel
                print("PluginModeController received signal from instance, passing it up.")
                self?.dataDidChange.send()
            }
        // 切换实例后，立即手动触发一次信号，以确保UI同步
        self.dataDidChange.send()
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