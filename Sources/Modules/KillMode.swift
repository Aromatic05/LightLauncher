import Foundation
import AppKit

// MARK: - 关闭应用命令
@MainActor
struct KillCommand: LauncherCommandHandler {
    let trigger = "/k"
    let description = "Close running applications"
    let mode = LauncherMode.kill
    
    func execute(in viewModel: LauncherViewModel) -> Bool {
        viewModel.switchToKillMode()
        return true
    }
    
    func handleInput(_ text: String, in viewModel: LauncherViewModel) {
        viewModel.filterRunningApps(searchText: text)
    }
    
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.killSelectedApp()
    }
}

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
class KillModeController: NSObject, ModeStateController {
    @Published var runningApps: [RunningAppInfo] = []
    var prefix: String? { "/k" }
    
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        runningApps.map { $0 as any DisplayableItem }
    }
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/k")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        runningApps = RunningAppsManager.shared.loadRunningApps()
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let all = RunningAppsManager.shared.loadRunningApps()
        runningApps = text.isEmpty ? all : RunningAppsManager.shared.filterRunningApps(all, with: text)
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        guard index < runningApps.count else { return false }
        let app = runningApps[index]
        return RunningAppsManager.shared.killApp(app)
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /k 前缀或切换到其他模式时退出
        return !text.hasPrefix("/k")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        runningApps = []
    }
}

// MARK: - LauncherViewModel 扩展 - 关闭应用模式
extension LauncherViewModel {
    // 兼容旧接口，转发到 StateController
    var runningApps: [RunningAppInfo] {
        (activeController as? KillModeController)?.runningApps ?? []
    }
    func switchToKillMode() {
        if let controller = activeController as? KillModeController {
            controller.enterMode(with: "", viewModel: self)
        }
    }
    func loadRunningApps() {
        if let controller = activeController as? KillModeController {
            controller.enterMode(with: "", viewModel: self)
        }
    }
    func filterRunningApps(searchText: String) {
        if let controller = activeController as? KillModeController {
            controller.handleInput(searchText, viewModel: self)
        }
    }
    func killSelectedApp() -> Bool {
        guard let killController = activeController as? KillModeController else { return false }
        return killController.executeAction(at: selectedIndex, viewModel: self)
    }
    func selectKillAppByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard let killController = activeController as? KillModeController else { return false }
        guard index >= 0 && index < killController.runningApps.count && index < 6 else { return false }
        selectedIndex = index
        return killSelectedApp()
    }
}

// MARK: - 关闭命令建议提供器
struct KillCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type '/k ' (with space) then search text to find running apps",
            "Example: '/k chrome' to search for Chrome",
            "Press ↑↓ arrows or numbers 1-6 to select", 
            "Delete /k prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}