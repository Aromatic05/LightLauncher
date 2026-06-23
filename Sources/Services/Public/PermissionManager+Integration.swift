//
//  PermissionManager+Integration.swift
//  LightLauncher
//
//  集成示例和便利方法

import Foundation

extension PermissionManager {

    // MARK: - 功能特定的权限检查

    /// 检查浏览器数据访问所需的权限
    func checkBrowserDataPermissions() -> Bool {
        return hasPermission(for: .fullDiskAccess)
    }

    /// 检查剪贴板管理所需的权限
    func checkClipboardPermissions() -> Bool {
        // 剪贴板访问通常不需要特殊权限，但可以扩展
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
