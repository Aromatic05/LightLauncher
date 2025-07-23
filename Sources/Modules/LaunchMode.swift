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
    private override init() {
        super.init()
        loadUsageData()
        setupObservers()
        // appScanner.scanForApplications()
    }
    var displayableItems: [any DisplayableItem] = []
    // 元信息属性
    var displayName: String { "Light Launcher" }
    var iconName: String { "magnifyingglass" }
    var placeholder: String { "Search applications..." }
    var modeDescription: String? { nil }

    // 应用列表和使用次数
    private(set) var allApps: [AppInfo] = []
    private var appUsageCount: [String: Int] = [:]
    private let appScanner = AppScanner.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var searchTextProvider: (() -> String)?
    
    // --- ModeStateController 协议实现 ---
    var prefix: String? { "" } // 启动模式无前缀
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        // 只要不是以/开头的命令，都可激活启动模式
        return text.isEmpty || !text.hasPrefix("/")
    }
    
    // 2. 进入模式
    func enterMode(with text: String) {
        let items = getMostUsedApps(from: allApps, limit: 6)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        LauncherViewModel.shared.selectedIndex = 0
    }
    
    // 3. 处理输入
    func handleInput(_ text: String) {
        filterApps(searchText: text)
    }
    
    // 4. 执行动作
    func executeAction(at index: Int) -> Bool {
        print("Executing action at index \(index)")
        guard index < self.displayableItems.count else { return false }
        guard let app = self.displayableItems[index] as? AppInfo else { return false }
        let success = NSWorkspace.shared.open(app.url)
        if success {
            incrementUsage(for: app.name)
        }
        return success
    }
    
    // 5. 退出条件
    func shouldExit(for text: String) -> Bool {
        // 以/开头的命令或切换到其他模式时退出
        return text.hasPrefix("/")
    }
    
    // 6. 清理操作
    func cleanup() {
        self.displayableItems = []
    }
    
    // --- 其他辅助方法 ---
    private func setupObservers() {
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                // 这里只能在外部调用 handleInput，不能假定有 shared 单例
            }
            .store(in: &cancellables)
    }
    
    func bindSearchTextProvider(_ provider: @escaping () -> String) {
        self.searchTextProvider = provider
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

    func filterApps(searchText: String) {
        if searchText.isEmpty {
            let items = getMostUsedApps(from: allApps, limit: 6)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            let matches = allApps.compactMap { app in
                calculateMatch(for: app, query: searchText)
            }
            // 按评分排序并取前6个
            let items = matches
                .sorted { $0.score > $1.score }
                .prefix(6)
                .map { $0.app }
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        // 每当列表更新时，重置选择
        LauncherViewModel.shared.selectedIndex = 0
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

    func launchSelectedApp(index: Int) -> Bool {
        return self.executeAction(at: index)
    }
    func getMostUsedDisplayApps(limit: Int) -> [AppInfo] {
        displayableItems.compactMap { $0 as? AppInfo }.prefix(limit).map { $0 }
    }
    func selectAppByNumber(_ number: Int) -> Bool {
        let idx = number - 1
        guard idx >= 0 && idx < self.displayableItems.count && idx < 6 else { return false }
        return self.executeAction(at: idx)
    }

    // 生成内容视图
    func makeContentView() -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyStateView(mode: .launch, hasSearchText: !LauncherViewModel.shared.searchText.isEmpty))
        }
    }

    func getHelpText() -> [String] {
        return [
            "Type to search applications",
            "Press ↑↓ arrows or numbers 1-6 to select",
            "Type / to see all commands",
            "Press Esc to close"
        ]
    }
}
