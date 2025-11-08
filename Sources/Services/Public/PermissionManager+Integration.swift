//
//  PermissionManager+Integration.swift
//  LightLauncher
//
//  集成示例和便利方法

import AppKit
import Foundation

extension PermissionManager {

    // MARK: - 功能特定的权限检查

    /// 检查浏览器数据访问所需的权限
    func checkBrowserDataPermissions() -> Bool {
        return hasPermission(for: .fullDiskAccess)
    }

    /// 检查剪切板管理所需的权限
    func checkClipboardPermissions() -> Bool {
        // 剪切板访问通常不需要特殊权限，但可以扩展
        return true
    }

    /// 检查进程管理所需的权限
    func checkProcessManagementPermissions() -> Bool {
        return hasPermission(for: .automation) && hasPermission(for: .accessibility)
    }

    /// 检查文件浏览所需的权限
    func checkFileBrowsingPermissions() -> Bool {
        return hasPermission(for: .fileAccess)
    }

    /// 检查终端命令执行所需的权限
    func checkTerminalPermissions() -> Bool {
        return hasPermission(for: .automation)
    }

    /// 检查插件系统所需的权限
    func checkPluginPermissions() -> Bool {
        // 插件系统的基础权限，具体权限由插件自己声明
        return hasPermission(for: .fileAccess)
    }

    // MARK: - 启动时权限检查

    /// 应用启动时进行权限检查
    @MainActor
    func performStartupPermissionCheck() {
        let summary = getPermissionSummary()
        if !summary.isFullyAuthorized {
            showPermissionReminder()
        }
    }

    // 已移除 showPermissionOnboarding 及相关调用

    /// 显示缺失权限说明弹窗（只显示缺失项及说明）
    @MainActor
    func showPermissionReminder() {
        resetPermissionAlertState()
        let missingPermissions = getMissingPermissions()
        guard !missingPermissions.isEmpty else { return }
        // 防止重复弹窗 - 使用一个特殊的key来跟踪权限提醒
        let reminderKey = AppPermissionType.automation
        if shouldSkipPermissionAlert(for: reminderKey) {
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要授权以下权限"
        let permissionList = missingPermissions.map { "• \($0.rawValue)：\($0.description)" }.joined(
            separator: "\n")
        alert.informativeText = "为了正常使用所有功能，需要授权以下权限：\n\n\(permissionList)\n\n建议逐个授权这些权限。"
        alert.addButton(withTitle: "逐个设置")
        alert.addButton(withTitle: "忽略")
        let response = alert.runModal()
        isShowingPermissionAlert = false
        if response == .alertFirstButtonReturn {
            // 逐个引导用户设置权限，无延迟
            Task { @MainActor in
                for permission in missingPermissions {
                    promptPermissionGuide(for: permission)
                }
            }
        }
    }

    // MARK: - 功能验证包装器

    /// 安全执行需要浏览器数据权限的操作
    @MainActor
    func withBrowserDataPermission(perform action: @escaping () -> Void) {
        if checkBrowserDataPermissions() {
            action()
        } else {
            promptPermissionGuide(for: .fullDiskAccess)
        }
    }

    /// 安全执行需要进程管理权限的操作
    @MainActor
    func withProcessManagementPermission(perform action: @escaping () -> Void) {
        if checkProcessManagementPermissions() {
            action()
        } else {
            if !hasPermission(for: .accessibility) {
                promptPermissionGuide(for: .accessibility)
            } else if !hasPermission(for: .automation) {
                promptPermissionGuide(for: .automation)
            }
        }
    }

    /// 安全执行注册全局快捷键的操作（无需权限）
    @MainActor
    func withGlobalHotKeyPermission(perform action: @escaping () -> Void) {
        // 注册快捷键无需权限，直接执行
        action()
    }

    // MARK: - 调试和诊断

    /// 生成权限诊断报告
    func generatePermissionDiagnostics() -> String {
        let summary = getPermissionSummary()
        var report = """
            LightLauncher 权限诊断报告
            ================================

            总体状态：\(summary.isFullyAuthorized ? "✅ 所有权限已授权" : "⚠️ 部分权限缺失")
            完成度：\(Int(summary.completionPercentage * 100))% (\(summary.granted)/\(summary.totalRequired))

            权限详情：
            """

        for type in AppPermissionType.allCases {
            let status = summary.allPermissions[type] == true ? "✅" : "❌"
            let required = getRequiredPermissions().contains(type) ? "[必需]" : "[可选]"
            report += "\n\(status) \(type.rawValue) \(required)"
        }

        if !summary.missingPermissions.isEmpty {
            report += "\n\n缺失的必需权限："
            for permission in summary.missingPermissions {
                report += "\n• \(permission.rawValue)：\(permission.description)"
            }
        }

        return report
    }

    /// 打印权限诊断信息到控制台
    func printPermissionDiagnostics() {
        Logger.shared.info(generatePermissionDiagnostics(), owner: self)
    }
}
