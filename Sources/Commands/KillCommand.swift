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
struct RunningAppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isHidden: Bool
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == processIdentifier }) {
            return app.icon
        }
        return nil
    }
    
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
        
        return runningApplications.compactMap { app in
            // 过滤掉系统应用和没有界面的应用
            guard let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName,
                  app.activationPolicy == .regular
            else {
                // !bundleId.hasPrefix("com.apple.") || appName.contains("Finder")
                return nil
            }
            
            return RunningAppInfo(
                name: appName,
                bundleIdentifier: bundleId,
                processIdentifier: app.processIdentifier,
                isHidden: app.isHidden
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

// MARK: - 关闭应用命令处理器
@MainActor
class KillCommandProcessor: CommandProcessor, ModeHandler {
    var prefix: String { "/k" }
    var mode: LauncherMode { .kill }
    
    func canHandle(command: String) -> Bool {
        return command == "/k"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        if command == "/k" {
            viewModel.switchToKillMode()
            return true
        }
        return false
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterRunningApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.killSelectedApp()
    }
}

// MARK: - 关闭应用模式处理器
@MainActor
class KillModeHandler: ModeHandler {
    let prefix = "/k"
    let mode = LauncherMode.kill
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.filterRunningApps(searchText: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.killSelectedApp()
    }
}

// MARK: - 關閉應用命令建議提供器
struct KillCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type after /k to search running apps",
            "Press ↑↓ arrows or numbers 1-6 to select", 
            "Delete /k prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}

// MARK: - 自动注册处理器
@MainActor
private let _autoRegisterKillProcessor: Void = {
    let processor = KillCommandProcessor()
    let modeHandler = KillModeHandler()
    ProcessorRegistry.shared.registerProcessor(processor)
    ProcessorRegistry.shared.registerModeHandler(modeHandler)
}()

// MARK: - LauncherViewModel 扩展 - 关闭应用模式
extension LauncherViewModel {
    func switchToKillMode() {
        mode = .kill
        // 不清空搜索文本，保持 "/k" 前缀
        // searchText = ""  // 注释掉这行
        loadRunningApps()
        selectedIndex = 0
    }
    
    func loadRunningApps() {
        runningApps = RunningAppsManager.shared.loadRunningApps()
    }
    
    func filterRunningApps(searchText: String) {
        let allRunningApps = RunningAppsManager.shared.loadRunningApps()
        runningApps = RunningAppsManager.shared.filterRunningApps(allRunningApps, with: searchText)
        selectedIndex = 0
    }
    
    func killSelectedApp() -> Bool {
        guard mode == .kill && selectedIndex < runningApps.count else { return false }
        let selectedApp = runningApps[selectedIndex]
        
        let success = RunningAppsManager.shared.killApp(selectedApp)
        if success {
            // 刷新运行应用列表
            loadRunningApps()
            // 调整选择索引
            if selectedIndex >= runningApps.count && runningApps.count > 0 {
                selectedIndex = runningApps.count - 1
            }
        }
        return success
    }
    
    func selectKillAppByNumber(_ number: Int) -> Bool {
        let index = number - 1 // 转换为0基础索引
        
        guard mode == .kill else { return false }
        guard index >= 0 && index < runningApps.count && index < 6 else { return false }
        selectedIndex = index
        return killSelectedApp()
    }
}
