import Foundation
import AppKit
import Combine

// MARK: - 基础命令协议
@MainActor
protocol LauncherCommandHandler {
    var trigger: String { get }
    var description: String { get }
    var mode: LauncherMode { get }
    
    func execute(in viewModel: LauncherViewModel) -> Bool
    func handleInput(_ text: String, in viewModel: LauncherViewModel)
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool
}

// MARK: - 默认启动命令
@MainActor
struct LaunchCommand: LauncherCommandHandler {
    let trigger = ""
    let description = "Launch applications"
    let mode = LauncherMode.launch
    
    func execute(in viewModel: LauncherViewModel) -> Bool {
        viewModel.switchToLaunchMode()
        return true
    }
    
    func handleInput(_ text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 启动命令处理器
@MainActor
class LaunchCommandProcessor: CommandProcessor, ModeHandler {
    var prefix: String { "" }
    var mode: LauncherMode { .launch }
    
    func canHandle(command: String) -> Bool {
        return command.isEmpty || !command.hasPrefix("/")
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 启动模式是默认模式，不需要特殊处理
        return false
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 启动模式处理器
@MainActor
class LaunchModeHandler: ModeHandler {
    let prefix = ""
    let mode = LauncherMode.launch
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        return false // 已经在启动模式，不需要切换
    }
    
    func extractSearchText(from text: String) -> String {
        return text // Launch模式没有前缀，直接返回原文本
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}

// MARK: - 应用信息结构
struct AppInfo: Identifiable, Hashable {
    let name: String
    let url: URL
    
    // 使用 URL 路径作为唯一标识符，避免重复应用
    var id: String {
        url.path
    }
    
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url.path == rhs.url.path
    }
}

// MARK: - 启动模式数据
struct LaunchModeData: ModeData {
    let apps: [AppInfo]
    
    var count: Int { apps.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < apps.count else { return nil }
        return apps[index]
    }
}

// MARK: - 启动命令建议提供器
struct LaunchCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type to search applications",
            "Press ↑↓ arrows or numbers 1-6 to select",
            "Type / to see all commands",
            "Press Esc to close"
        ]
    }
}

// MARK: - 应用匹配结果结构
struct AppMatch {
    let app: AppInfo
    let score: Double
    let matchType: MatchType
    
    enum MatchType {
        case exactStart      // 完全匹配开头
        case wordStart       // 单词开头匹配
        case subsequence     // 子序列匹配
        case fuzzy          // 模糊匹配
        case contains       // 包含匹配
    }
}

// MARK: - LauncherViewModel 扩展 - 启动模式
extension LauncherViewModel {
    // 兼容旧接口，转发到 StateController
    var filteredApps: [AppInfo] {
        (activeController as? LaunchStateController)?.filteredApps ?? []
    }
    func switchToLaunchMode() {
        (activeController as? LaunchStateController)?.activate()
    }
    func switchToLaunchModeAndClear() {
        (activeController as? LaunchStateController)?.activate()
        searchText = ""
    }
    func filterApps(searchText: String) {
        (activeController as? LaunchStateController)?.update(for: searchText)
    }
    func launchSelectedApp() -> Bool {
        guard let launchController = activeController as? LaunchStateController else { return false }
        let result = launchController.executeAction(at: selectedIndex)
        return result == .hideWindow
    }
    func incrementUsage(for appName: String) {
        // 仅用于兼容旧接口，实际应由 StateController 内部管理
    }
    func getMostUsedApps(from apps: [AppInfo], limit: Int) -> [AppInfo] {
        (activeController as? LaunchStateController)?.displayableItems.prefix(limit).compactMap { $0 as? AppInfo } ?? []
    }
    func selectAppByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard let launchController = activeController as? LaunchStateController else { return false }
        guard index >= 0 && index < launchController.filteredApps.count && index < 6 else { return false }
        selectedIndex = index
        return launchSelectedApp()
    }
}

// 启动模式 StateController
import AppKit

@MainActor
class LaunchStateController: NSObject, ModeStateController {
    @Published var filteredApps: [AppInfo] = []
    // 公开属性，便于 ViewModel 兼容接口访问
    var allApps: [AppInfo]
    var appUsageCount: [String: Int]
    private let appScanner: AppScanner
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var searchTextProvider: (() -> String)?

    var displayableItems: [any DisplayableItem] {
        filteredApps
    }
    
    let mode: LauncherMode = .launch

    override init() {
        self.allApps = []
        self.appUsageCount = [:]
        self.appScanner = AppScanner()
        super.init()
        loadUsageData()
        setupObservers()
        appScanner.scanForApplications()
    }

    func activate() {
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
    }

    func deactivate() {
        filteredApps = []
    }
    
    private func setupObservers() {
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                self.update(for: self.searchTextProvider?() ?? "")
            }
            .store(in: &cancellables)
    }

    // 提供外部注入 searchText 的闭包
    func bindSearchTextProvider(_ provider: @escaping () -> String) {
        self.searchTextProvider = provider
    }

    // --- 全局辅助方法和初始化逻辑 ---
    private func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            self.appUsageCount = data
        }
    }
    private func saveUsageData() {
        userDefaults.set(appUsageCount, forKey: "appUsageCount")
    }

    func update(for searchText: String) {
        if searchText.isEmpty {
            filteredApps = getMostUsedApps(from: allApps, limit: 6)
        } else {
            filteredApps = allApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func executeAction(at index: Int) -> PostAction? {
        guard index < filteredApps.count else { return nil }
        let app = filteredApps[index]
        let success = NSWorkspace.shared.open(app.url)
        if success {
            incrementUsage(for: app.name)
            return .hideWindow
        }
        return .keepWindowOpen
    }

    private func incrementUsage(for appName: String) {
        appUsageCount[appName, default: 0] += 1
        // 可在此处添加持久化逻辑
    }

    private func getMostUsedApps(from apps: [AppInfo], limit: Int) -> [AppInfo] {
        apps.sorted { app1, app2 in
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
}
