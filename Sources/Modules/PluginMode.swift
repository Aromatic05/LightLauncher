import SwiftUI
import Combine

@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()

    // MARK: - ModeStateController Protocol Implementation
    let mode: LauncherMode = .plugin
    let prefix: String? = "/p"
    let displayName: String = "Plugins"
    let iconName: String = "puzzlepiece.extension"
    var placeholder: String {
        currentPlugin?.manifest.placeholder ?? "Enter plugin command..."
    }
    var modeDescription: String? = "Extend functionality with plugins"
    
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

    // func executeAction(at index: Int) -> Bool {
    //     if case .showingPluginList(let items) = internalMode {
    //         guard index >= 0 && index < items.count,
    //               let action = items[index].action,
    //               action.hasPrefix("select_plugin:") else {
    //             return false
    //         }
    //         let command = String(action.dropFirst("select_plugin:".count))
    //         handleInput(arguments: command)
    //         return true
    //     }
        
    //     guard let instance = activeInstance, index >= 0 && index < instance.currentItems.count,
    //           let pluginItem = instance.currentItems[index] as? PluginItem,
    //           let action = pluginItem.action else {
    //         return false
    //     }
    //     return instance.executeAction(action)
    // }

    func cleanup() {
        activeInstance = nil
        currentPlugin = nil
        internalMode = .runningInstance
        lastInput = ""
        errorMessage = nil
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
                action: "select_plugin:\(plugin.command)"
            )
        }
        self.internalMode = .showingPluginList(items)
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
        activeInstance = pluginExecutor.getInstance(for: plugin.name) ?? pluginExecutor.createInstance(for: plugin)
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