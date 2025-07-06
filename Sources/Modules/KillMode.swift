import Foundation
import AppKit
import SwiftUI

// MARK: - 运行中应用信息结构
struct RunningAppInfo: Identifiable, Hashable, DisplayableItem {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isHidden: Bool
    var title: String { name }
    var subtitle: String? { bundleIdentifier }
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == processIdentifier }) {
            return app.icon
        }
        return nil
    }
    // DisplayableItem 协议实现
    var displayName: String { name }
    // 如有其它协议要求属性/方法，请在此补充
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 关闭模式数据
struct KillModeData: ModeData {
    let runningApps: [RunningAppInfo]
    
    var count: Int { runningApps.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < runningApps.count else { return nil }
        return runningApps[index]
    }
}

// MARK: - 运行应用管理器
@MainActor
class RunningAppsManager: @unchecked Sendable {
    static let shared = RunningAppsManager()
    
    private init() {}
    
    func loadRunningApps() -> [RunningAppInfo] {
        let workspace = NSWorkspace.shared
        let runningApplications = workspace.runningApplications
        
        let validApps = runningApplications.compactMap { app -> RunningAppInfo? in
            guard app.activationPolicy == .regular else { return nil }
            guard let bundleId = app.bundleIdentifier else { return nil }
            guard let appName = app.localizedName, !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            // 过滤掉包含非法字符的名称
            if appName.rangeOfCharacter(from: .controlCharacters) != nil { return nil }
            return RunningAppInfo(
                name: appName,
                bundleIdentifier: bundleId,
                processIdentifier: app.processIdentifier,
                isHidden: app.isHidden
            )
        }
        return validApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func filterRunningApps(_ apps: [RunningAppInfo], with searchText: String) -> [RunningAppInfo] {
        if searchText.isEmpty {
            return apps
        }
        
        let searchLower = searchText.lowercased()
        return apps.filter { app in
            app.name.lowercased().contains(searchLower)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func killApp(_ app: RunningAppInfo) -> Bool {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.processIdentifier == app.processIdentifier 
        }) {
            return runningApp.terminate()
        }
        return false
    }
}

// MARK: - 关闭应用模式控制器
@MainActor
class KillModeController: NSObject, ModeStateController, ObservableObject {
    var displayableItems: [any DisplayableItem] = []

    var prefix: String? { "/k" }
    // 可显示项插槽
    // var displayableItems: [any DisplayableItem] {
    //     runningApps.map { $0 as any DisplayableItem }
    // }
    // 工具方法：生成“当前可关闭应用项”
    private func makeKillItems(for text: String) -> [RunningAppInfo] {
        let all = RunningAppsManager.shared.loadRunningApps()
        let prefix = "/k"
        let trimmedText: String
        if text.hasPrefix(prefix + " ") {
            trimmedText = String(text.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasPrefix(prefix) {
            trimmedText = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmedText.isEmpty {
            return all
        } else {
            return RunningAppsManager.shared.filterRunningApps(all, with: trimmedText)
        }
    }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/k")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        let items = makeKillItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let items = makeKillItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        guard index < self.displayableItems.count else { return false }
        guard let app = self.displayableItems[index] as? RunningAppInfo else { return false }
        return RunningAppsManager.shared.killApp(app)
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /k 前缀或切换到其他模式时退出
        return !text.hasPrefix("/k")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        self.displayableItems = []
    }

    static func getHelpText() -> [String] {
        return [
            "Type '/k ' (with space) then search text to find running apps",
            "Example: '/k chrome' to search for Chrome",
            "Press ↑↓ arrows or numbers 1-6 to select", 
            "Delete /k prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
    // 其它便捷方法
    func reloadApps(viewModel: LauncherViewModel) {
        enterMode(with: "", viewModel: viewModel)
    }
    func filterApps(searchText: String, viewModel: LauncherViewModel) {
        handleInput(searchText, viewModel: viewModel)
    }
    func killSelectedApp(selectedIndex: Int, viewModel: LauncherViewModel) -> Bool {
        return executeAction(at: selectedIndex, viewModel: viewModel)
    }
    func selectKillAppByNumber(_ number: Int, viewModel: LauncherViewModel) -> Bool {
        let index = number - 1
        guard index >= 0 && index < displayableItems.count && index < 6 else { return false }
        return executeAction(at: index, viewModel: viewModel)
    }
    // 生成内容视图
    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: viewModel))
        } else {
            return AnyView(EmptyStateView(mode: .kill, hasSearchText: !viewModel.searchText.isEmpty))
        }
    }
}