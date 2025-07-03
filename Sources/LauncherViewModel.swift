import Foundation
import Combine
import AppKit

@MainActor
class LauncherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var filteredApps: [AppInfo] = []
    @Published var mode: LauncherMode = .launch
    @Published var runningApps: [RunningAppInfo] = []
    @Published var commandSuggestions: [LauncherCommand] = []
    @Published var showCommandSuggestions = false
    @Published var browserItems: [BrowserItem] = []
    @Published var searchHistory: [SearchHistoryItem] = []
    
    // 文件管理器相关属性
    @Published var currentFiles: [FileItem] = []
    @Published var currentPath: String = NSHomeDirectory()
    
    // 文件浏览器起始路径
    @Published var fileBrowserStartPaths: [FileBrowserStartPath] = []
    @Published var showStartPaths: Bool = true
    
    // 插件相关属性
    @Published var pluginItems: [PluginItem] = []
    private var activePlugin: Plugin?

    // 剪切板模式相关属性
    @Published var currentClipItems: [ClipboardItem] = []

    // 将私有属性改为内部访问级别，供 Commands 扩展使用
    var allApps: [AppInfo] = []
    // 使用频率统计 - 改为内部访问级别
    var appUsageCount: [String: Int] = [:]
    private let userDefaults = UserDefaults.standard
    private let appScanner: AppScanner
    private var cancellables = Set<AnyCancellable>()
    private let commandProcessor = MainCommandProcessor()
    private let runningAppsManager = RunningAppsManager.shared
    private let browserDataManager = BrowserDataManager.shared
    
    // 新增 Facade 属性
    lazy var facade: LauncherFacade = LauncherFacade(viewModel: self)

    init(appScanner: AppScanner) {
        self.appScanner = appScanner
        // 其余初始化和方法调用
        loadUsageData()
        setupObservers()
        initializeBrowserData()
        // 设置全局处理器注册
        ProcessorRegistry.shared.setMainProcessor(commandProcessor)
        // 手动注册所有处理器和模式处理器
        registerAllProcessors()
    }
    
    private func initializeBrowserData() {
        // 从配置管理器同步启用的浏览器设置
        let enabledBrowsers = ConfigManager.shared.getEnabledBrowsers()
        browserDataManager.setEnabledBrowsers(enabledBrowsers)
        
        // 初始加载浏览器数据
        browserDataManager.loadBrowserData()
    }
    
    private func setupObservers() {
        // 监听 AppScanner 的应用列表
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                // 初始加载时，显示最常用的前6个应用
                self.filteredApps = self.getMostUsedApps(from: apps, limit: 6)
                self.selectedIndex = 0
            }
            .store(in: &cancellables)
        
        // 监听搜索文本的变化
        $searchText
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 命令处理
    
    private func handleSearchTextChange(text: String) {
        // 检查是否应该显示命令建议
        updateCommandSuggestions(for: text)
        
        // 使用命令处理器处理输入
        _ = commandProcessor.processInput(text, in: self)
    }
    
    private func updateCommandSuggestions(for text: String) {
        if commandProcessor.shouldShowCommandSuggestions() && text.hasPrefix("/") {
            // 获取所有命令建议
            let allCommands = commandProcessor.getCommandSuggestions(for: text)
            
            // 如果用户输入了具体的命令前缀（不只是 "/"），进行过滤
            if text.count > 1 {
                let searchPrefix = text.lowercased()
                commandSuggestions = allCommands.filter { command in
                    command.trigger.lowercased().hasPrefix(searchPrefix) ||
                    command.description.lowercased().contains(searchPrefix.dropFirst())
                }
            } else {
                // 如果只是 "/"，显示所有命令
                commandSuggestions = allCommands
            }
            
            showCommandSuggestions = !commandSuggestions.isEmpty
            
            // 重置选择索引
            if !commandSuggestions.isEmpty {
                selectedIndex = 0
            }
        } else {
            showCommandSuggestions = false
            commandSuggestions = []
        }
    }
    
    // MARK: - 模式切换
    
    func resetToLaunchMode() {
        // 如果当前在插件模式，先清理插件状态
        if mode == .plugin {
            clearPluginState()
        }
        
        mode = .launch
        searchText = ""
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
        selectedIndex = 0
        searchHistory = []
    }
    
    // MARK: - 通用方法
    
    func executeSelectedAction() -> Bool {
        return commandProcessor.executeAction(at: selectedIndex, in: self)
    }
    
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }
    
    // MARK: - 导航和选择
    
    func moveSelectionUp() {
        guard !getCurrentItems().isEmpty else { return }
        let itemCount = getCurrentItems().count
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : itemCount - 1
    }
    
    func moveSelectionDown() {
        guard !getCurrentItems().isEmpty else { return }
        let itemCount = getCurrentItems().count
        selectedIndex = selectedIndex < itemCount - 1 ? selectedIndex + 1 : 0
    }
    
    // MARK: - 状态属性
    
    var hasResults: Bool {
        switch mode {
        case .launch:
            return !filteredApps.isEmpty
        case .kill:
            return !runningApps.isEmpty
        case .web:
            return !browserItems.isEmpty
        case .search, .terminal:
            return true
        case .file:
            return showStartPaths ? !fileBrowserStartPaths.isEmpty : !currentFiles.isEmpty
        case .clip:
            return !currentClipItems.isEmpty
        case .plugin:
            return true // 插件模式总是显示，由插件控制内容
        }
    }
    
    var selectedApp: AppInfo? {
        guard selectedIndex < filteredApps.count else { return nil }
        return filteredApps[selectedIndex]
    }
    
    // MARK: - 使用频率管理
    
    private func loadUsageData() {
        if let data = UserDefaults.standard.object(forKey: "appUsageCount") as? [String: Int] {
            appUsageCount = data
        }
    }
    
    private func saveUsageData() {
        UserDefaults.standard.set(appUsageCount, forKey: "appUsageCount")
    }
    
    func getCurrentItems() -> [Any] {
        switch mode {
        case .launch:
            return filteredApps
        case .kill:
            return runningApps
        case .web:
            // Web模式：当前输入项（索引0） + 浏览器项目（索引1开始）
            var items: [Any] = ["current_web"] // 当前输入项在最前面
            items.append(contentsOf: browserItems) // 浏览器项目在后面
            return items
        case .search:
            // 搜索模式：当前输入项（索引0） + 历史记录（索引1开始）
            var items: [Any] = ["current_search"] // 当前搜索项在最前面
            items.append(contentsOf: searchHistory) // 历史记录在后面
            return items
        case .terminal:
            // 终端模式：只有当前输入项
            return ["current_terminal"]
        case .file:
            // 文件模式：显示起始路径或当前目录的文件和文件夹
            return showStartPaths ? fileBrowserStartPaths : currentFiles
        case .clip:
            return currentClipItems
        case .plugin:
            // 插件模式：返回插件项目
            return pluginItems
        }
    }
    
    // MARK: - 辅助方法供内部使用
    
    // 暴露给 Commands 扩展使用的保存方法
    func saveUsageDataPublic() {
        saveUsageData()
    }
    
    private func registerAllProcessors() {
        // 注册启动模式处理器
        let launchProcessor = LaunchCommandProcessor()
        let launchModeHandler = LaunchModeHandler()
        commandProcessor.registerProcessor(launchProcessor)
        commandProcessor.registerModeHandler(launchModeHandler)
        
        // 注册关闭应用处理器
        let killProcessor = KillCommandProcessor()
        let killModeHandler = KillModeHandler()
        commandProcessor.registerProcessor(killProcessor)
        commandProcessor.registerModeHandler(killModeHandler)
        
        // 注册搜索处理器
        let searchProcessor = SearchCommandProcessor()
        let searchModeHandler = SearchModeHandler()
        commandProcessor.registerProcessor(searchProcessor)
        commandProcessor.registerModeHandler(searchModeHandler)
        
        // 注册网页处理器
        let webProcessor = WebCommandProcessor()
        let webModeHandler = WebModeHandler()
        commandProcessor.registerProcessor(webProcessor)
        commandProcessor.registerModeHandler(webModeHandler)
        
        // 注册终端处理器
        let terminalProcessor = TerminalCommandProcessor()
        let terminalModeHandler = TerminalModeHandler()
        commandProcessor.registerProcessor(terminalProcessor)
        commandProcessor.registerModeHandler(terminalModeHandler)
        
        // 注册文件处理器
        let fileProcessor = FileCommandProcessor()
        let fileModeHandler = FileModeHandler()
        commandProcessor.registerProcessor(fileProcessor)
        commandProcessor.registerModeHandler(fileModeHandler)
        
        // 注册插件处理器
        let pluginProcessor = PluginCommandProcessor()
        commandProcessor.registerProcessor(pluginProcessor)
        commandProcessor.registerModeHandler(pluginProcessor)
        
        // 注册剪切板处理器
        let clipProcessor = ClipCommandProcessor()
        let clipModeHandler = ClipModeHandler()
        commandProcessor.registerProcessor(clipProcessor)
        commandProcessor.registerModeHandler(clipModeHandler)
    }
    
    // MARK: - 插件模式支持
    
    /// 切换到插件模式
    func switchToPluginMode(with plugin: Plugin) {
        mode = .plugin
        activePlugin = plugin
        pluginItems = []
        selectedIndex = 0
    }
    
    /// 获取当前激活的插件
    func getActivePlugin() -> Plugin? {
        return activePlugin
    }
    
    /// 获取插件的窗口隐藏设置
    func getPluginShouldHideWindowAfterAction() -> Bool {
        guard mode == .plugin,
              let plugin = activePlugin else {
            return true // 默认隐藏窗口
        }
        
        return PluginManager.shared.getPluginShouldHideWindowAfterAction(command: plugin.command)
    }
    
    /// 更新插件结果
    func updatePluginResults(_ items: [PluginItem]) {
        pluginItems = items
        selectedIndex = 0
    }
    
    /// 执行插件动作
    func executePluginAction() -> Bool {
        guard mode == .plugin,
              selectedIndex < pluginItems.count else {
            return false
        }
        
        // 获取插件处理器
        if let pluginProcessor = commandProcessor.getCommandProcessor(for: .plugin) as? PluginCommandProcessor {
            return pluginProcessor.executeAction(at: selectedIndex, in: self)
        }
        
        return false
    }
    
    /// 处理插件搜索
    func handlePluginSearch(_ text: String) {
        guard mode == .plugin else { return }
        
        // 获取插件处理器
        if let pluginProcessor = commandProcessor.getCommandProcessor(for: .plugin) as? PluginCommandProcessor {
            pluginProcessor.handleSearch(text: text, in: self)
        }
    }
    
    /// 清除插件状态
    func clearPluginState() {
        activePlugin = nil
        pluginItems = []
        
        // 同时清理插件处理器的状态
        if let pluginProcessor = commandProcessor.getCommandProcessor(for: .plugin) as? PluginCommandProcessor {
            pluginProcessor.clearState()
        }
    }
    
    /// 获取当前模式的项目数量
    var currentModeItemCount: Int {
        switch mode {
        case .launch:
            return filteredApps.count
        case .kill:
            return runningApps.count
        case .search, .web:
            return browserItems.count
        case .terminal:
            return searchHistory.count
        case .file:
            return currentFiles.count
        case .clip:
            return currentClipItems.count
        case .plugin:
            return pluginItems.count
        }
    }
    
    // MARK: - 命令建议处理
    
    /// 处理命令建议的选择导航
    func moveCommandSuggestionUp() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
    }
    
    func moveCommandSuggestionDown() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
    }
    
    /// 选择当前命令建议
    func selectCurrentCommandSuggestion() -> Bool {
        guard showCommandSuggestions,
              selectedIndex >= 0,
              selectedIndex < commandSuggestions.count else { return false }
        
        let selectedCommand = commandSuggestions[selectedIndex]
        applySelectedCommand(selectedCommand)
        return true
    }
    
    /// 应用选中的命令
    func applySelectedCommand(_ command: LauncherCommand) {
        // 更新搜索文本为选中的命令
        searchText = command.trigger + " "
        // 隐藏命令建议
        showCommandSuggestions = false
        commandSuggestions = []
        // 重置选择索引
        selectedIndex = 0
        // 处理命令执行
        _ = commandProcessor.processInput(command.trigger, in: self)
    }
    
    /// 隐藏启动器窗口
    func hideLauncher() {
        NotificationCenter.default.post(name: .hideWindow, object: nil)
    }
}
