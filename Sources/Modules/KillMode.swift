import Foundation
import AppKit
import SwiftUI

// MARK: - 运行中应用信息结构
struct RunningAppInfo: Identifiable, Hashable, DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(RunningAppRowView(app: self, isSelected: isSelected, index: index))
    }
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
final class KillModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = KillModeController()
    private override init() {}
    var displayableItems: [any DisplayableItem] = []
    var prefix: String? { "/k" }
    // 元信息属性
    var displayName: String { "Kill Mode" }
    var iconName: String { "xmark.circle" }
    var placeholder: String { "Search running apps to close..." }
    var modeDescription: String? { "Enter kill mode to close running applications" }
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
    func enterMode(with text: String) {
        let items = makeKillItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        LauncherViewModel.shared.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String) {
        let items = makeKillItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        LauncherViewModel.shared.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int) -> Bool {
        guard index < self.displayableItems.count else { return false }
        guard let app = self.displayableItems[index] as? RunningAppInfo else { return false }
        let result = RunningAppsManager.shared.killApp(app)
        // 无论 killApp 是否成功，直接移除该项
        self.displayableItems.remove(at: index)
        return result
    }
    // 5. 退出条件
    func shouldExit(for text: String) -> Bool {
        // 删除 /k 前缀或切换到其他模式时退出
        return !text.hasPrefix("/k")
    }
    // 6. 清理操作
    func cleanup() {
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
    func reloadApps() {
        enterMode(with: "")
    }
    func filterApps(searchText: String) {
        handleInput(searchText)
    }
    func killSelectedApp(selectedIndex: Int) -> Bool {
        return executeAction(at: selectedIndex)
    }
    func selectKillAppByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard index >= 0 && index < displayableItems.count && index < 6 else { return false }
        return executeAction(at: index)
    }
    func makeContentView() -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyStateView(mode: .kill, hasSearchText: !LauncherViewModel.shared.searchText.isEmpty))
        }
    }
    // makeRowView 已由 RunningAppInfo 实现，无需在控制器中实现
}