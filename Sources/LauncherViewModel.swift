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
    
    func switchToKillMode() {
        mode = .kill
        // 不清空搜索文本，保持 "/k" 前缀
        // searchText = ""  // 注释掉这行
        loadRunningApps()
        selectedIndex = 0
    }
    
    func switchToLaunchMode() {
        mode = .launch
        searchText = ""
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
        selectedIndex = 0
    }
    
    // MARK: - 运行应用管理
    
    func loadRunningApps() {
        runningApps = runningAppsManager.loadRunningApps()
    }
    
    func filterRunningApps(searchText: String) {
        let allRunningApps = runningAppsManager.loadRunningApps()
        runningApps = runningAppsManager.filterRunningApps(allRunningApps, with: searchText)
        selectedIndex = 0
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
    
    private func incrementUsage(for appName: String) {
        appUsageCount[appName, default: 0] += 1
        saveUsageData()
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
    
    // MARK: - 智能搜索算法
    
    func filterApps(searchText: String) {
        if searchText.isEmpty {
            filteredApps = getMostUsedApps(from: allApps, limit: 6)
        } else {
            let matches = allApps.compactMap { app in
                calculateMatch(for: app, query: searchText)
            }
            
            // 按评分排序并取前6个
            filteredApps = matches
                .sorted { $0.score > $1.score }
                .prefix(6)
                .map { $0.app }
        }
        // 每当列表更新时，重置选择
        selectedIndex = 0
    }
    
    private func calculateMatch(for app: AppInfo, query: String) -> AppMatch? {
        let commonAbbreviations = ConfigManager.shared.config.commonAbbreviations
        return AppSearchMatcher.calculateMatch(
            for: app,
            query: query,
            usageCount: appUsageCount,
            commonAbbreviations: commonAbbreviations
        )
    }
    
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
    
    func killSelectedApp() -> Bool {
        guard mode == .kill && selectedIndex < runningApps.count else { return false }
        let selectedApp = runningApps[selectedIndex]
        
        let success = runningAppsManager.killApp(selectedApp)
        if success {
            // 刷新运行应用列表
            loadRunningApps()
            // 调整选择索引
            if selectedIndex >= runningApps.count && runningApps.count > 0 {
                selectedIndex = runningApps.count - 1
            }
        }
        return success
    }
    
    func executeSelectedAction() -> Bool {
        return commandProcessor.executeAction(at: selectedIndex, in: self)
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
            let cleanText = extractCleanTerminalText()
            return cleanText.isEmpty ? [] : ["current_terminal"]
        case .file:
            // 文件模式：显示起始路径或当前目录的文件和文件夹
            return showStartPaths ? fileBrowserStartPaths : currentFiles
        }
    }
    
    private func extractCleanWebText() -> String {
        let prefix = "/w "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractCleanSearchText() -> String {
        let prefix = "/s "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractCleanTerminalText() -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func launchSelectedApp() -> Bool {
        guard selectedIndex < filteredApps.count else { return false }
        let selectedApp = filteredApps[selectedIndex]
        
        let success = NSWorkspace.shared.open(selectedApp.url)
        
        if success {
            // 记录使用频率
            incrementUsage(for: selectedApp.name)
            clearSearch()
        }
        
        return success
    }
    
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }
    
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
    
    func selectAppByNumber(_ number: Int) -> Bool {
        let index = number - 1 // 转换为0基础索引
        
        switch mode {
        case .launch:
            guard index >= 0 && index < filteredApps.count && index < 6 else { return false }
            selectedIndex = index
            
            let selectedApp = filteredApps[selectedIndex]
            let success = NSWorkspace.shared.open(selectedApp.url)
            
            if success {
                // 记录使用频率
                incrementUsage(for: selectedApp.name)
                clearSearch()
            }
            
            return success
            
        case .kill:
            guard index >= 0 && index < runningApps.count && index < 6 else { return false }
            selectedIndex = index
            return killSelectedApp()
            
        case .web, .search, .terminal, .file:
            // 这些模式不支持数字选择，只能通过方向键和回车选择
            return false
        }
    }
    
    // MARK: - 清理方法
    
    func resetToLaunchMode() {
        mode = .launch
        searchText = ""
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
        selectedIndex = 0
        searchHistory = []
    }
    
    // MARK: - 搜索历史方法
    
    func updateSearchHistory(_ items: [SearchHistoryItem]) {
        searchHistory = items
        // 确保选中索引在有效范围内
        let maxIndex = getCurrentItems().count - 1
        if selectedIndex > maxIndex {
            selectedIndex = 0
        }
    }
    
    func executeSearchHistoryItem(at index: Int) -> Bool {
        guard index >= 0 && index < searchHistory.count else { return false }
        let item = searchHistory[index]
        
        // 直接执行网页搜索，避免递归
        let configManager = ConfigManager.shared
        let engine = configManager.config.modes.defaultSearchEngine
        
        var searchEngine: String
        switch engine {
        case "baidu":
            searchEngine = "https://www.baidu.com/s?wd={query}"
        case "bing":
            searchEngine = "https://www.bing.com/search?q={query}"
        case "google":
            fallthrough
        default:
            searchEngine = "https://www.google.com/search?q={query}"
        }
        
        let encodedQuery = item.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.query
        let searchURL = searchEngine.replacingOccurrences(of: "{query}", with: encodedQuery)
        
        guard let url = URL(string: searchURL) else { return false }
        
        // 保存到搜索历史（更新使用时间）
        SearchHistoryManager.shared.addSearch(query: item.query, searchEngine: engine)
        
        NSWorkspace.shared.open(url)
        resetToLaunchMode()
        return true
    }
    
    func clearSearchHistory() {
        SearchHistoryManager.shared.clearHistory()
        searchHistory = []
    }
    
    func removeSearchHistoryItem(_ item: SearchHistoryItem) {
        SearchHistoryManager.shared.removeSearch(item: item)
        searchHistory = SearchHistoryManager.shared.searchHistory
    }
}
