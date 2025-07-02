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
