import AppKit
import Foundation

@MainActor
final class AlertService {
    static let shared = AlertService()

    private init() {}

    func showDirectoryAccessError(forPath path: String, error: Error? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法访问目录"

        if let error {
            alert.informativeText =
                "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。\n\n错误详情：\(error.localizedDescription)"
            alert.addButton(withTitle: "检查权限")
            alert.addButton(withTitle: "确定")

            if alert.runModal() == .alertFirstButtonReturn {
                PermissionPromptService.shared.prompt(for: .fileAccess)
            }
            return
        }

        alert.informativeText = "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    func showBrokenSymlinkError(forPath path: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "符号链接目标不存在"
        alert.informativeText = "路径 '\(path)' 是一个符号链接，但其目标不存在或不可访问。请检查符号链接或目标路径。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    func showInformation(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
