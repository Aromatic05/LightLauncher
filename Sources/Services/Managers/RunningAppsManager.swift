import AppKit
import Foundation
import SwiftUI

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
            guard let appName = app.localizedName,
                !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            // 过滤掉包含非法字符的名称
            if appName.rangeOfCharacter(from: .controlCharacters) != nil { return nil }
            return RunningAppInfo(
                name: appName,
                bundleIdentifier: bundleId,
                processIdentifier: app.processIdentifier,
                isHidden: app.isHidden
            )
        }
        return validApps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
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

    /// 结束应用，支持强制结束
    func killApp(_ app: RunningAppInfo, force: Bool = false) -> Bool {
        // 检查进程管理权限
        guard PermissionManager.shared.checkProcessManagementPermissions() else {
            let missingPermission: AppPermissionType =
                PermissionManager.shared.hasPermission(for: .accessibility)
                ? .automation
                : .accessibility
            PermissionPromptService.shared.prompt(for: missingPermission)
            return false
        }

        guard
            let runningApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.processIdentifier == app.processIdentifier
            })
        else {
            return false
        }
        if force {
            return runningApp.forceTerminate()
        } else {
            return runningApp.terminate()
        }
    }
}
