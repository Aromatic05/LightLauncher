import AppKit
import Combine
import Foundation
// MARK: - 关闭应用模式控制器
import SwiftUI

@MainActor
final class KillModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = KillModeController()
    private override init() {}
    @Published var forceKillEnabled: Bool = false {
        didSet {
            guard forceKillEnabled != oldValue else { return }
            dataDidChange.send()
        }
    }

    // MARK: - ModeStateController Protocol Implementation
    // 1. 身份与元数据
    let mode: LauncherMode = .kill
    let prefix: String? = "/k"
    var displayName: String {
        forceKillEnabled ? "强制结束" : "结束进程"
    }
    let commandDisplayName: String = "结束进程"
    let iconName: String = "xmark.circle"
    let placeholder: String = "搜索运行中的应用..."
    let modeDescription: String? = "结束正在运行的应用"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    var interceptedKeys: Set<KeyEvent> {
        return [
            .numeric(1), .numeric(2), .numeric(3),
            .numeric(4), .numeric(5), .numeric(6),
        ]
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .numeric(let number) where number >= 1 && number <= 6:
            if selectKillAppByNumber(Int(number)) {
                LauncherViewModel.shared.hideWindow()
            }
            return true
        case .optionFlagChanged:
            if .optionFlagChanged(isPressed: true) == keyEvent {
                forceKillEnabled.toggle()
            }
            return true
        default:
            return false
        }
    }

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        let items = filterRunningApps(with: arguments)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.displayableItems = []
        self.forceKillEnabled = false
    }

    func makeContentView() -> AnyView {
        if !displayableItems.isEmpty {
            return AnyView(KillModeView(viewModel: LauncherViewModel.shared))
        } else {
            let hasSearchText = !LauncherViewModel.shared.searchText.isEmpty
            return AnyView(
                EmptyStateView(
                    icon: "xmark.circle",
                    iconColor: hasSearchText ? .red.opacity(0.5) : .red.opacity(0.7),
                    title: hasSearchText ? "未找到运行中的应用" : "暂无可关闭的应用",
                    description: hasSearchText
                        ? "请尝试其他搜索关键词"
                        : "输入 \(commandReference()) 后可搜索应用进程",
                    helpTexts: getHelpText()
                ))
        }
    }

    func getHelpText() -> [String] {
        return [
            "输入应用名过滤运行中的应用",
            "按 Enter 结束选中的进程",
            "按 Option 在普通结束和强制结束间切换",
            "按 Esc 退出",
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
        return displayableItems[index].executeAction()
    }
}
