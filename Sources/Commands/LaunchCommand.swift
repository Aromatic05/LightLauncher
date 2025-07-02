import Foundation
import AppKit

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
    func switchToLaunchMode() {
        mode = .launch
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
        selectedIndex = 0
    }
    
    func switchToLaunchModeAndClear() {
        mode = .launch
        searchText = ""
        filteredApps = getMostUsedApps(from: allApps, limit: 6)
        selectedIndex = 0
    }
    
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
    
    func incrementUsage(for appName: String) {
        appUsageCount[appName, default: 0] += 1
        saveUsageDataPublic()
    }
    
    func getMostUsedApps(from apps: [AppInfo], limit: Int) -> [AppInfo] {
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
    
    func selectAppByNumber(_ number: Int) -> Bool {
        let index = number - 1 // 转换为0基础索引
        
        guard mode == .launch else { return false }
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
    }
}

// MARK: - 自动注册处理器
@MainActor
private let _autoRegisterLaunchProcessor: Void = {
    let processor = LaunchCommandProcessor()
    let modeHandler = LaunchModeHandler()
    ProcessorRegistry.shared.registerProcessor(processor)
    ProcessorRegistry.shared.registerModeHandler(modeHandler)
}()
