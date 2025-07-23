import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 关闭应用模式控制器
import SwiftUI

@MainActor
final class KillModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = KillModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation
    // 1. 身份与元数据
    let mode: LauncherMode = .kill
    let prefix: String? = "/k"
    let displayName: String = "Kill Process"
    let iconName: String = "xmark.circle"
    let placeholder: String = "Search running apps to kill..."
    let modeDescription: String? = "Force quit a running application"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()
    
    // 2. 核心逻辑
    func handleInput(arguments: String) {
        let items = filterRunningApps(with: arguments)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index < self.displayableItems.count,
              let app = self.displayableItems[index] as? RunningAppInfo else {
            return false
        }
        let result = RunningAppsManager.shared.killApp(app)
        if result {
            self.displayableItems.remove(at: index)
        }
        return result
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.displayableItems = []
    }

    func makeContentView() -> AnyView {
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            let hasSearchText = !LauncherViewModel.shared.searchText.isEmpty
            return AnyView(EmptyStateView(
                icon: "xmark.circle",
                iconColor: hasSearchText ? .red.opacity(0.5) : .red.opacity(0.7),
                title: hasSearchText ? "未找到运行中的应用" : "暂无可关闭的应用",
                description: hasSearchText ? "请尝试其他搜索关键词" : "输入 /k 后可搜索应用进程",
                helpTexts: getHelpText()
            ))
        }
    }
    
    func getHelpText() -> [String] {
        return [
            "Type to filter running applications",
            "Press Enter to kill the selected process",
            "Press Esc to exit"
        ]
    }
    
    private func filterRunningApps(with query: String) -> [RunningAppInfo] {
        let allApps = RunningAppsManager.shared.loadRunningApps()
        if query.isEmpty {
            return allApps
        }
        return RunningAppsManager.shared.filterRunningApps(allApps, with: query)
    }

    func selectKillAppByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard index >= 0 && index < displayableItems.count && index < 6 else { return false }
        return executeAction(at: index)
    }
}