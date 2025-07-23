import Foundation
import AppKit
import Combine
import SwiftUI

// MARK: - 应用信息结构
struct AppInfo: Identifiable, Hashable, DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(AppRowView(app: self, isSelected: isSelected, index: index, mode: .launch))
    }
    let name: String
    let url: URL
    
    // 使用 URL 路径作为唯一标识符，避免重复应用
    var id: String {
        url.path
    }
    
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    // DisplayableItem 协议实现
    var displayName: String { name }
    var title: String { name }
    var subtitle: String? { url.path }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url.path == rhs.url.path
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

// MARK: - 启动模式控制器
@MainActor
final class LaunchModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = LaunchModeController()
    
    // 1. 身份与元数据
    let mode: LauncherMode = .launch
    let prefix: String? = nil // Launch 模式作为默认模式，没有前缀
    let displayName: String = "Light Launcher"
    let iconName: String = "magnifyingglass"
    let placeholder: String = "Search applications or type / for commands..."
    let modeDescription: String? = nil
    
    // 2. 核心逻辑 (单一输入入口)
    func handleInput(arguments: String) {
        filterApps(searchText: arguments)
    }
    
    /// 执行选中项的动作：启动应用
    func executeAction(at index: Int) -> Bool {
        guard index < self.displayableItems.count else { return false }
        guard let app = self.displayableItems[index] as? AppInfo else { return false }
        
        let success = NSWorkspace.shared.open(app.url)
        if success {
            incrementUsage(for: app.name)
        }
        return success
    }
    
    // 3. 生命周期与UI
    
    /// 清理操作：清空显示列表
    func cleanup() {
        self.displayableItems = []
    }
    
    /// 用于 UI 绑定的可显示项目
    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    /// 创建 SwiftUI 视图
    func makeContentView() -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            // 当没有搜索结果时，显示空状态视图
            let hasSearchText = !LauncherViewModel.shared.searchText.isEmpty
            let icon = hasSearchText ? "magnifyingglass" : "app.badge"
            let iconColor: Color = hasSearchText ? .secondary.opacity(0.5) : .accentColor.opacity(0.7)
            let title = hasSearchText ? "未找到应用" : "开始输入以搜索应用"
            let description = hasSearchText ? "请尝试其他搜索关键词" : nil
            let helpTexts = getHelpText()
            return AnyView(EmptyStateView(
                icon: icon,
                iconColor: iconColor,
                title: title,
                description: description,
                helpTexts: helpTexts
            ))
        }
    }
    
    /// 获取帮助文本
    func getHelpText() -> [String] {
        return [
            "Type to search applications",
            "Press ↑↓ arrows or numbers 1-6 to select",
            "Type / to see all commands",
            "Press Esc to close"
        ]
    }

    // MARK: - Private Properties & Methods
    
    private(set) var allApps: [AppInfo] = []
    private var appUsageCount: [String: Int] = [:]
    private let appScanner = AppScanner.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        loadUsageData()
        setupObservers()
        // 初始的应用扫描可以在这里触发
        // appScanner.scanForApplications()
    }
    
    private func setupObservers() {
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                // 当应用列表更新时，如果当前是 launch 模式，可以刷新一下显示
                if LauncherViewModel.shared.mode == .launch {
                    self.handleInput(arguments: LauncherViewModel.shared.searchText)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            self.appUsageCount = data
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

    /// 核心过滤逻辑，现在由 handleInput 调用
    private func filterApps(searchText: String) {
        if searchText.isEmpty {
            // 如果输入为空，显示最常用的应用
            let items = getMostUsedApps(from: allApps, limit: 6)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            // 如果有输入，则进行模糊匹配搜索
            let matches = allApps.compactMap { app in
                calculateMatch(for: app, query: searchText)
            }
            let items = matches
                .sorted { $0.score > $1.score }
                .prefix(6)
                .map { $0.app }
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        
        // 每当列表更新时，重置 ViewModel 中的选择索引
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
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

    // --- 其他特定于此控制器的公共方法 ---
    
    func selectAppByNumber(_ number: Int) -> Bool {
        let idx = number - 1
        guard idx >= 0 && idx < self.displayableItems.count && idx < 6 else { return false }
        return self.executeAction(at: idx)
    }
}
