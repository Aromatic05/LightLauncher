import Foundation
import Combine
import AppKit

@MainActor
class LauncherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var mode: LauncherMode = .launch {
        didSet {
            switchController(from: oldValue, to: mode)
        }
    }
    @Published var commandSuggestions: [LauncherCommand] = []
    @Published var showCommandSuggestions = false
    @Published private(set) var activeController: (any ModeStateController)?

    private var controllers: [LauncherMode: any ModeStateController] = [:]
    private let appScanner: AppScanner
    private var cancellables = Set<AnyCancellable>()
    private let commandProcessor = MainCommandProcessor()
    private let runningAppsManager = RunningAppsManager.shared
    private let browserDataManager = BrowserDataManager.shared
    private let userDefaults = UserDefaults.standard
    var allApps: [AppInfo] = []
    var appUsageCount: [String: Int] = [:]
    // 其他全局依赖...

    // 新增 Facade 属性
    lazy var facade: LauncherFacade = LauncherFacade(viewModel: self)

    // 插件激活状态
    private var activePlugin: Plugin?

    init(appScanner: AppScanner) {
        self.appScanner = appScanner
        loadUsageData()
        setupControllers()
        setupObservers()
        initializeBrowserData()
        ProcessorRegistry.shared.setMainProcessor(commandProcessor)
        registerAllProcessors()
        switchController(from: nil, to: .launch)
    }

    private func setupControllers() {
        let appUsageData = appUsageCount
        controllers[.launch] = LaunchStateController(allApps: appScanner.applications, usageCount: appUsageData)
        controllers[.kill] = KillStateController()
        controllers[.file] = FileStateController()
        controllers[.plugin] = PluginStateController()
        controllers[.search] = SearchStateController()
        controllers[.web] = WebStateController()
        controllers[.clip] = ClipStateController()
    }

    private func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        if let oldMode = oldMode, let oldController = controllers[oldMode] {
            oldController.deactivate()
        }
        if let newController = controllers[newMode] {
            activeController = newController
            newController.activate()
            newController.update(for: searchText)
        }
        selectedIndex = 0
    }

    private func setupObservers() {
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                if let launchController = self.controllers[.launch] as? LaunchStateController {
                    launchController.update(for: self.searchText)
                }
                self.selectedIndex = 0
            }
            .store(in: &cancellables)
        $searchText
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }

    private func handleSearchTextChange(text: String) {
        updateCommandSuggestions(for: text)
        activeController?.update(for: text)
        _ = commandProcessor.processInput(text, in: self)
    }

    private func updateCommandSuggestions(for text: String) {
        if commandProcessor.shouldShowCommandSuggestions() && text.hasPrefix("/") {
            let allCommands = commandProcessor.getCommandSuggestions(for: text)
            if text.count > 1 {
                let searchPrefix = text.lowercased()
                commandSuggestions = allCommands.filter { command in
                    command.trigger.lowercased().hasPrefix(searchPrefix) ||
                    command.description.lowercased().contains(searchPrefix.dropFirst())
                }
            } else {
                commandSuggestions = allCommands
            }
            showCommandSuggestions = !commandSuggestions.isEmpty
            if !commandSuggestions.isEmpty {
                selectedIndex = 0
            }
        } else {
            showCommandSuggestions = false
            commandSuggestions = []
        }
    }

    func executeSelectedAction() -> Bool {
        guard let controller = activeController else { return false }
        if let postAction = controller.executeAction(at: selectedIndex) {
            if postAction == .hideWindow {
                hideLauncher()
            }
            return true
        }
        return false
    }

    func moveSelectionUp() {
        guard let items = activeController?.displayableItems, !items.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : items.count - 1
    }

    func moveSelectionDown() {
        guard let items = activeController?.displayableItems, !items.isEmpty else { return }
        selectedIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
    }

    var hasResults: Bool {
        return !(activeController?.displayableItems.isEmpty ?? true)
    }

    // --- 全局辅助方法和初始化逻辑 ---
    private func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            appUsageCount = data
        }
    }
    private func saveUsageData() {
        userDefaults.set(appUsageCount, forKey: "appUsageCount")
    }
    private func initializeBrowserData() {
        let enabledBrowsers = ConfigManager.shared.getEnabledBrowsers()
        browserDataManager.setEnabledBrowsers(enabledBrowsers)
        browserDataManager.loadBrowserData()
    }
    private func registerAllProcessors() {
        let launchProcessor = LaunchCommandProcessor()
        let launchModeHandler = LaunchModeHandler()
        commandProcessor.registerProcessor(launchProcessor)
        commandProcessor.registerModeHandler(launchModeHandler)
        let killProcessor = KillCommandProcessor()
        let killModeHandler = KillModeHandler()
        commandProcessor.registerProcessor(killProcessor)
        commandProcessor.registerModeHandler(killModeHandler)
        let searchProcessor = SearchCommandProcessor()
        let searchModeHandler = SearchModeHandler()
        commandProcessor.registerProcessor(searchProcessor)
        commandProcessor.registerModeHandler(searchModeHandler)
        let webProcessor = WebCommandProcessor()
        let webModeHandler = WebModeHandler()
        commandProcessor.registerProcessor(webProcessor)
        commandProcessor.registerModeHandler(webModeHandler)
        let terminalProcessor = TerminalCommandProcessor()
        let terminalModeHandler = TerminalModeHandler()
        commandProcessor.registerProcessor(terminalProcessor)
        commandProcessor.registerModeHandler(terminalModeHandler)
        let fileProcessor = FileCommandProcessor()
        let fileModeHandler = FileModeHandler()
        commandProcessor.registerProcessor(fileProcessor)
        commandProcessor.registerModeHandler(fileModeHandler)
        let pluginProcessor = PluginCommandProcessor()
        commandProcessor.registerProcessor(pluginProcessor)
        commandProcessor.registerModeHandler(pluginProcessor)
        let clipProcessor = ClipCommandProcessor()
        let clipModeHandler = ClipModeHandler()
        commandProcessor.registerProcessor(clipProcessor)
        commandProcessor.registerModeHandler(clipModeHandler)
    }
    func hideLauncher() {
        NotificationCenter.default.post(name: .hideWindow, object: nil)
    }

    // --- 交互与命令建议相关方法 ---
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }
    func getPluginShouldHideWindowAfterAction() -> Bool {
        guard mode == .plugin, let plugin = activePlugin else {
            return true // 默认隐藏窗口
        }
        return PluginManager.shared.getPluginShouldHideWindowAfterAction(command: plugin.command)
    }
    func applySelectedCommand(_ command: LauncherCommand) {
        searchText = command.trigger + " "
        showCommandSuggestions = false
        commandSuggestions = []
        selectedIndex = 0
        _ = commandProcessor.processInput(command.trigger, in: self)
    }
    func moveCommandSuggestionUp() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
    }
    func moveCommandSuggestionDown() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
    }
    // --- 恢复所有原有方法，保留全局交互、插件、命令建议等逻辑 ---
    // 插件相关
    func switchToPluginMode(with plugin: Plugin) {
        mode = .plugin
        activePlugin = plugin
        selectedIndex = 0
    }
    func getActivePlugin() -> Plugin? {
        return activePlugin
    }
    func updatePluginResults(_ items: [PluginItem]) {
        if let pluginController = controllers[.plugin] as? PluginStateController {
            pluginController.pluginItems = items
        }
        selectedIndex = 0
    }
    func executePluginAction() -> Bool {
        guard mode == .plugin, let pluginController = controllers[.plugin] as? PluginStateController else { return false }
        return pluginController.executeAction(at: selectedIndex) == .hideWindow
    }
    func handlePluginSearch(_ text: String) {
        guard mode == .plugin, let pluginController = controllers[.plugin] as? PluginStateController else { return }
        pluginController.update(for: text)
    }
    func clearPluginState() {
        activePlugin = nil
        if let pluginController = controllers[.plugin] as? PluginStateController {
            pluginController.pluginItems = []
        }
    }
    // 命令建议相关
    func selectCurrentCommandSuggestion() -> Bool {
        guard showCommandSuggestions,
              selectedIndex >= 0,
              selectedIndex < commandSuggestions.count else { return false }
        let selectedCommand = commandSuggestions[selectedIndex]
        applySelectedCommand(selectedCommand)
        return true
    }
    // 兼容接口：插件模式结果
    var pluginItems: [PluginItem] {
        (activeController as? PluginStateController)?.pluginItems ?? []
    }
    // 兼容接口：在 Finder 中显示当前选中文件或文件夹
    func openSelectedFileInFinder() {
        guard mode == .file,
              let fileController = controllers[.file] as? FileStateController,
              !showStartPaths,
              let fileItem = getFileItem(at: selectedIndex) else { return }
        fileController.openInFinder(fileItem.url)
    }
    // 兼容接口：搜索历史
    var searchHistory: [SearchHistoryItem] {
        (activeController as? SearchStateController)?.searchHistory ?? []
    }
    // 兼容接口：获取当前模式下所有可显示项
    func getCurrentItems() -> [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }
}
