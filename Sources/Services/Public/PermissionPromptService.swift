import AppKit
import Foundation

@MainActor
final class PermissionPromptService {
    static let shared = PermissionPromptService()

    private var shownPermissionAlerts: [AppPermissionType: Date] = [:]
    private let alertCooldownInterval: TimeInterval = 300
    private var isShowingPermissionAlert = false

    private init() {}

    func prompt(for type: AppPermissionType) {
        Logger.shared.debug("Requesting permission prompt for: \(type)", owner: self)
        guard !shouldSkipPrompt(for: type) else { return }

        isShowingPermissionAlert = true
        shownPermissionAlerts[type] = Date()

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要\(type.rawValue)权限"
        alert.informativeText = type.description
        alert.addButton(withTitle: "前往设置")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        isShowingPermissionAlert = false

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

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要授权以下权限"
        let permissionList = missingPermissions
            .map { "• \($0.rawValue)：\($0.description)" }
            .joined(separator: "\n")
        alert.informativeText = "为了正常使用所有功能，需要授权以下权限：\n\n\(permissionList)\n\n建议逐个授权这些权限。"
        alert.addButton(withTitle: "逐个设置")
        alert.addButton(withTitle: "忽略")

        let response = alert.runModal()
        isShowingPermissionAlert = false

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
