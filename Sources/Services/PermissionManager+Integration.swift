//
//  PermissionManager+Integration.swift
//  LightLauncher
//
//  集成示例和便利方法

import Foundation
import AppKit

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
            showPermissionOnboardingIfNeeded()
        }
    }
    
    /// 显示权限引导界面（如果需要）
    @MainActor
    private func showPermissionOnboardingIfNeeded() {
        let userDefaults = UserDefaults.standard
        let hasShownOnboarding = userDefaults.bool(forKey: "HasShownPermissionOnboarding")
        
        if !hasShownOnboarding {
            showPermissionOnboarding()
            userDefaults.set(true, forKey: "HasShownPermissionOnboarding")
        } else {
            // 已经显示过引导，但仍有缺失权限，显示简短提醒
            showPermissionReminder()
        }
    }
    
    /// 显示完整的权限引导
    @MainActor
    private func showPermissionOnboarding() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "欢迎使用 LightLauncher"
        alert.informativeText = """
        为了获得最佳使用体验，LightLauncher 需要一些系统权限：
        
        • 辅助功能：用于全局快捷键和应用控制
        • 完全磁盘访问：读取浏览器书签和历史记录
        • 输入监控：全局键盘快捷键监听
        • 自动化：控制其他应用程序
        
        您可以稍后在设置中管理这些权限。
        """
        
        alert.addButton(withTitle: "立即设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            promptAllMissingPermissions()
        }
    }
    
    /// 显示权限提醒
    @MainActor
    private func showPermissionReminder() {
        let missingCount = getMissingPermissions().count
        guard missingCount > 0 else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "权限不完整"
        alert.informativeText = "当前有 \(missingCount) 个权限未授权，某些功能可能无法正常使用。是否前往设置？"
        
        alert.addButton(withTitle: "前往设置")
        alert.addButton(withTitle: "忽略")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            promptAllMissingPermissions()
        }
    }
    
    // MARK: - 功能验证包装器
    
    /// 安全执行需要浏览器数据权限的操作
    @MainActor
    func withBrowserDataPermission(perform action: @escaping () -> Void) {
        if checkBrowserDataPermissions() {
            action()
        } else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "需要完全磁盘访问权限"
            alert.informativeText = "访问浏览器书签和历史记录需要完全磁盘访问权限。"
            alert.addButton(withTitle: "前往设置")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                promptPermissionGuide(for: .fullDiskAccess)
            }
        }
    }
    
    /// 安全执行需要进程管理权限的操作
    @MainActor
    func withProcessManagementPermission(perform action: @escaping () -> Void) {
        if checkProcessManagementPermissions() {
            action()
        } else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "需要应用控制权限"
            alert.informativeText = "结束其他应用的进程需要辅助功能和自动化权限。"
            alert.addButton(withTitle: "前往设置")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if !hasPermission(for: .accessibility) {
                    promptPermissionGuide(for: .accessibility)
                } else if !hasPermission(for: .automation) {
                    promptPermissionGuide(for: .automation)
                }
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
        print(generatePermissionDiagnostics())
    }
}
