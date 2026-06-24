import AppKit
import Foundation

@MainActor
final class AlertService {
    static let shared = AlertService()

    private init() {}

    @discardableResult
    func presentAlert(
        style: NSAlert.Style,
        title: String,
        message: String,
        buttons: [String] = ["确定"]
    ) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        return alert.runModal()
    }

    func showDirectoryAccessError(forPath path: String, error: Error? = nil) {
        if let error {
            let response = presentAlert(
                style: .warning,
                title: "无法访问目录",
                message:
                    "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。\n\n错误详情：\(error.localizedDescription)",
                buttons: ["检查权限", "确定"]
            )

            if response == .alertFirstButtonReturn {
                PermissionPromptService.shared.prompt(for: .fileAccess)
            }
            return
        }

        presentAlert(
            style: .warning,
            title: "无法访问目录",
            message: "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。"
        )
    }

    func showBrokenSymlinkError(forPath path: String) {
        presentAlert(
            style: .warning,
            title: "符号链接目标不存在",
            message: "路径 '\(path)' 是一个符号链接，但其目标不存在或不可访问。请检查符号链接或目标路径。"
        )
    }

    func showInformation(title: String, message: String) {
        presentAlert(style: .informational, title: title, message: message)
    }

    func showWarning(title: String, message: String) {
        presentAlert(style: .warning, title: title, message: message)
    }
}
