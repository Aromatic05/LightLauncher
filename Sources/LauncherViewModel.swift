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

    private var allApps: [AppInfo] = []
    private let appScanner: AppScanner
    private var cancellables = Set<AnyCancellable>()
    private let commandProcessor = MainCommandProcessor()
    private let runningAppsManager = RunningAppsManager.shared
    private let browserDataManager = BrowserDataManager.shared
    
    // 公共方法供其他地方访问
    func getBrowserDataManager() -> BrowserDataManager {
        return browserDataManager
    }
    
    // 使用频率统计
    private var appUsageCount: [String: Int] = [:]
    private let userDefaults = UserDefaults.standard
    
    init(appScanner: AppScanner) {
        self.appScanner = appScanner
        loadUsageData()
        setupObservers()
        initializeBrowserData()
        
        // 设置全局处理器注册
        ProcessorRegistry.shared.setMainProcessor(commandProcessor)
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
                self?.allApps = apps
                // 初始加载时，显示最常用的前6个应用
                self?.filteredApps = self?.getMostUsedApps(from: apps, limit: 6) ?? []
                self?.selectedIndex = 0
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
        if commandProcessor.shouldShowCommandSuggestions() && text == "/" {
            commandSuggestions = commandProcessor.getCommandSuggestions(for: text)
            showCommandSuggestions = true
        } else {
            showCommandSuggestions = false
            commandSuggestions = []
        }
    }
    
    // MARK: - 模式切换
    
    func resetToLaunchMode() {
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
    
    func selectAppByNumber(_ number: Int) -> Bool {
        let index = number - 1 // 转换为0基础索引
        
        switch mode {
        case .launch:
            return selectAppByNumber(number)
        case .kill:
            return selectKillAppByNumber(number)
        case .web, .search, .terminal, .file:
            // 这些模式不支持数字选择，只能通过方向键和回车选择
            return false
        }
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
            // 对于这些模式，总是显示输入框
            return true
        case .file:
            return showStartPaths ? !fileBrowserStartPaths.isEmpty : !currentFiles.isEmpty
        }
    }
    
    var selectedApp: AppInfo? {
        guard selectedIndex < filteredApps.count else { return nil }
        return filteredApps[selectedIndex]
    }
    
    // MARK: - 使用频率管理
    
    private func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            appUsageCount = data
        }
    }
    
    private func saveUsageData() {
        userDefaults.set(appUsageCount, forKey: "appUsageCount")
    }
    
    private func getMostUsedApps(from apps: [AppInfo], limit: Int) -> [AppInfo] {
        return apps
            .sorted { app1, app2 in
                let usage1 = appUsageCount[app1.name, default: 0]
                let usage2 = appUsageCount[app2.name, default: 0]
                if usage1 != usage2 {
                    return usage1 > usage2
                }
                return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
    
    private func getCurrentItems() -> [Any] {
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
        }
    }
}
