import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - 应用匹配结果结构
struct AppMatch {
    let app: AppInfo
    let score: Double
    let matchType: MatchType

    enum MatchType {
        case exactStart  // 完全匹配开头
        case wordStart  // 单词开头匹配
        case subsequence  // 子序列匹配
        case fuzzy  // 模糊匹配
        case contains  // 包含匹配
    }
}

// MARK: - 启动模式控制器
@MainActor
final class LaunchModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = LaunchModeController()
    private let systemCommandManager = SystemCommandManager.shared

    // 1. 身份与元数据
    let mode: LauncherMode = .launch
    let prefix: String? = nil  // Launch 模式作为默认模式，没有前缀
    let displayName: String = "Light Launcher"
    let iconName: String = "magnifyingglass"
    let placeholder: String = "Search applications or type / for commands..."
    let modeDescription: String? = nil
    var interceptedKeys: Set<KeyEvent> {
        return [
            .numeric(1), .numeric(2), .numeric(3),
            .numeric(4), .numeric(5), .numeric(6),
        ]
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .numeric(let number) where number >= 1 && number <= 6:
            if displayableItems[Int(number) - 1].executeAction() {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
            return true
        default:
            return false
        }
    }

    // 2. 核心逻辑 (单一输入入口)
    func handleInput(arguments: String) {
        filterApps(searchText: arguments)
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
            let iconColor: Color =
                hasSearchText ? .secondary.opacity(0.5) : .accentColor.opacity(0.7)
            let title = hasSearchText ? "未找到应用" : "开始输入以搜索应用"
            let description = hasSearchText ? "请尝试其他搜索关键词" : nil
            let helpTexts = getHelpText()
            return AnyView(
                EmptyStateView(
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
            "Press Esc to close",
        ]
    }

    // MARK: - Private Properties & Methods

    private(set) var allApps: [AppInfo] = []
    private(set) var allPanes: [PreferencePaneItem] = []
    private var appUsageCount: [String: Int] = [:]
    private let appScanner = AppScanner.shared
    private let paneScanner = PreferencePaneScanner()
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        loadUsageData()
        setupObservers()
    }

    private func setupObservers() {
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                self.allApps = apps
                if LauncherViewModel.shared.mode == .launch {
                    self.handleInput(arguments: LauncherViewModel.shared.searchText)
                }
            }
            .store(in: &cancellables)
        paneScanner.$panes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] panes in
                guard let self = self else { return }
                self.allPanes = panes
                if LauncherViewModel.shared.mode == .launch {
                    self.handleInput(arguments: LauncherViewModel.shared.searchText)
                }
            }
            .store(in: &cancellables)
        // 启动扫描
        appScanner.scanForApplications()
        paneScanner.scanForPreferencePanes()
    }

    func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            self.appUsageCount = data
        }
    }

    func saveUsageData() {
        userDefaults.set(appUsageCount, forKey: "appUsageCount")
    }

    func incrementUsage(for appName: String) {
        appUsageCount[appName, default: 0] += 1
        saveUsageData()
    }

    private func getMostUsedItems(limit: Int) -> [any DisplayableItem] {
        let allItems: [any DisplayableItem] = allApps + allPanes + systemCommandManager.commands
        return allItems.sorted { item1, item2 in
            let usage1 = appUsageCount[item1.title, default: 0]
            let usage2 = appUsageCount[item2.title, default: 0]
            if usage1 != usage2 {
                return usage1 > usage2
            }
            return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    /// 核心过滤逻辑，现在由 handleInput 调用
    private func filterApps(searchText: String) {
        let allItems: [any DisplayableItem] = allApps + allPanes + systemCommandManager.commands
        let commonAbbreviations = ConfigManager.shared.config.commonAbbreviations
        if searchText.isEmpty {
            // 显示最常用的应用、设置项和系统命令
            let items = allItems.sorted { item1, item2 in
                let usage1 = appUsageCount[item1.title, default: 0]
                let usage2 = appUsageCount[item2.title, default: 0]
                if usage1 != usage2 {
                    return usage1 > usage2
                }
                return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
            }
            .prefix(6)
            .map { $0 }
            self.displayableItems = items
        } else {
            // 统一评分与排序
            let matches = allItems.compactMap { item in
                AppSearchMatcher.calculateMatch(
                    for: item,
                    query: searchText,
                    usageCount: appUsageCount,
                    commonAbbreviations: commonAbbreviations
                )
            }
            let sorted = matches.sorted { $0.score > $1.score }
            let items: [any DisplayableItem] = sorted.prefix(6).map { $0.item }
            self.displayableItems = items
        }
        // 每当列表更新时，重置 ViewModel 中的选择索引
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    // 已统一到 AppSearchMatcher.calculateMatch(for: item, ...)

    func selectAppByNumber(_ number: Int) -> Bool {
        let idx = number - 1
        guard idx >= 0 && idx < self.displayableItems.count && idx < 6 else { return false }
        return self.displayableItems[idx].executeAction()
    }
}
