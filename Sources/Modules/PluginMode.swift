import Combine
import Foundation

@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()

    // MARK: - ModeStateController Protocol Implementation
    let mode: LauncherMode = .plugin
    let prefix: String? = "/p"
    var displayName: String {
        currentPlugin?.manifest.displayName ?? "插件"
    }
    let commandDisplayName: String = "插件模式"
    let iconName: String = "puzzlepiece.extension"
    var placeholder: String {
        currentPlugin?.manifest.placeholder ?? "输入插件命令..."
    }
    var modeDescription: String? {
        currentPlugin?.description ?? "通过插件扩展更多功能"
    }

    let dataDidChange = PassthroughSubject<Void, Never>()

    var displayableItems: [any DisplayableItem] {
        switch internalMode {
        case .showingPluginList(let items):
            return items
        case .runningInstance:
            return activeInstance?.currentItems ?? []
        }
    }

    // MARK: - Core Logic
    func handleInput(arguments: String) {
        self.lastInput = arguments
        Task {
            await processPluginInput(arguments)
        }
    }

    func cleanup() {
        activeInstance = nil
        currentPlugin = nil
        internalMode = .runningInstance
        lastInput = ""
        errorMessage = nil
    }

    func getHelpText() -> [String] {
        let plugins = pluginManager.getEnabledPlugins()
        var helpTexts = ["可用插件:"]
        if plugins.isEmpty {
            helpTexts.append("- 暂无可用插件。")
        } else {
            plugins.forEach { helpTexts.append("- \($0.command): \($0.description)") }
        }
        return helpTexts
    }

    // MARK: - Internal Plugin System
    private enum InternalMode {
        case runningInstance
        case showingPluginList([PluginItem])
    }

    private var internalMode: InternalMode = .runningInstance {
        didSet {
            dataDidChange.send()
        }
    }

    @Published private(set) var currentPlugin: Plugin?
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
    private var instanceCancellable: AnyCancellable?

    private init() {}

    private func processPluginInput(_ text: String) async {
        let components = text.components(separatedBy: " ")
        guard let command = components.first, !command.isEmpty else {
            showAvailablePlugins()
            return
        }

        self.internalMode = .runningInstance

        let args = components.count > 1 ? Array(components.dropFirst()).joined(separator: " ") : ""

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
                action: .selectPlugin(command: plugin.command)
            )
        }
        self.internalMode = .showingPluginList(items)
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func showPluginNotFound(command: String) {
        let item = PluginItem(
            title: "未找到插件命令：\(command)",
            subtitle: "输入 '\(commandReference())' 查看可用插件",
            iconName: "questionmark.circle",
            action: nil
        )
        self.internalMode = .showingPluginList([item])
        self.currentPlugin = nil
        self.activeInstance = nil
    }

    private func switchToPlugin(_ plugin: Plugin, input: String) async {
        self.internalMode = .runningInstance
        if currentPlugin?.name == plugin.name, let instance = activeInstance {
            instance.handleInput(input)
            return
        }
        currentPlugin = plugin
        activeInstance =
            pluginExecutor.getInstance(for: plugin.name)
            ?? pluginExecutor.createInstance(for: plugin)
        guard let instance = activeInstance else {
            errorMessage = "Failed to create instance for plugin: \(plugin.name)"
            return
        }
        instance.handleInput(input)
    }

    private func setupInstanceSubscription() {
        instanceCancellable?.cancel()
        if case .runningInstance = internalMode, let instance = activeInstance {
            instanceCancellable = instance.dataDidChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.dataDidChange.send()
                }
        }
        self.dataDidChange.send()
    }

    // MARK: - Public Plugin Management API
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
