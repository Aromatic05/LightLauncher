import AppKit
import Foundation

@MainActor
final class PermissionPromptService {
    static let shared = PermissionPromptService()

    private let alertService = AlertService.shared
    private var shownPermissionAlerts: [AppPermissionType: Date] = [:]
    private let alertCooldownInterval: TimeInterval = 300
    private var isShowingPermissionAlert = false

    private init() {}

    func prompt(for type: AppPermissionType) {
        Logger.shared.debug("Requesting permission prompt for: \(type)", owner: self)
        guard !shouldSkipPrompt(for: type) else { return }

        isShowingPermissionAlert = true
        shownPermissionAlerts[type] = Date()
        defer { isShowingPermissionAlert = false }

        let response = alertService.presentAlert(
            style: .informational,
            title: "需要\(type.rawValue)权限",
            message: type.description,
            buttons: ["前往设置", "取消"]
        )

        if response == .alertFirstButtonReturn {
            PermissionManager.shared.openSystemPreferences(for: type)
        }
    }

    func showReminder(for missingPermissions: [AppPermissionType]) {
        reset()
        guard !missingPermissions.isEmpty else { return }

        let reminderKey = AppPermissionType.automation
        guard !shouldSkipPrompt(for: reminderKey) else { return }

        isShowingPermissionAlert = true
        shownPermissionAlerts[reminderKey] = Date()
        let permissionList = missingPermissions
            .map { "• \($0.rawValue)：\($0.description)" }
            .joined(separator: "\n")
        defer { isShowingPermissionAlert = false }

        let response = alertService.presentAlert(
            style: .warning,
            title: "需要授权以下权限",
            message: "为了正常使用所有功能，需要授权以下权限：\n\n\(permissionList)\n\n建议逐个授权这些权限。",
            buttons: ["逐个设置", "忽略"]
        )

        guard response == .alertFirstButtonReturn else { return }
        for permission in missingPermissions {
            prompt(for: permission)
        }
    }

    func reset() {
        shownPermissionAlerts.removeAll()
        isShowingPermissionAlert = false
    }

    private func shouldSkipPrompt(for type: AppPermissionType) -> Bool {
        guard !isShowingPermissionAlert else { return true }
        guard let lastShownTime = shownPermissionAlerts[type] else { return false }
        return Date().timeIntervalSince(lastShownTime) < alertCooldownInterval
    }
}
