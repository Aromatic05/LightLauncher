import AppKit
import Foundation

@MainActor
final class PermissionSettingsService {
    static let shared = PermissionSettingsService()

    private let permissionManager = PermissionManager.shared
    private let promptService = PermissionPromptService.shared
    private let alertService = AlertService.shared

    private init() {}

    func refreshSummary(delayNanoseconds: UInt64 = 500_000_000) async -> AppPermissionSummary {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return permissionManager.getPermissionSummary()
    }

    func promptForPermission(_ type: AppPermissionType) {
        promptService.prompt(for: type)
    }

    func promptForMissingPermissions() {
        promptService.showReminder(for: permissionManager.getMissingPermissions())
    }

    func copyDiagnosticsToClipboard() {
        ClipboardService.shared.copy(permissionManager.generatePermissionDiagnostics())
        alertService.showInformation(
            title: "诊断报告已复制",
            message: "权限诊断报告已复制到剪贴板，您可以粘贴到文本编辑器中查看。"
        )
    }

    func openPrivacySettings() {
        permissionManager.openSystemPreferences(for: .fileAccess)
    }
}
