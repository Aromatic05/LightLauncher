import Foundation
import ApplicationServices
import AppKit

/// 权限类型枚举
enum AppPermissionType: String, CaseIterable {
    case accessibility = "辅助功能"
    case automation = "自动化"
    // 可扩展更多权限类型，如屏幕录制、文件访问等
}

/// 权限管理器，统一检测和引导用户授权敏感权限
class PermissionManager {
    @MainActor static let shared = PermissionManager()
    private init() {}

    /// 有权限则执行，无权限则引导用户授权
    @MainActor
    func withAccessibilityPermission(perform action: @escaping () -> Void) {
        if isAccessibilityGranted() {
            action()
        } else {
            promptAccessibilityGuide()
        }
    }

    /// 检查辅助功能权限
    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// 引导用户前往系统设置授权辅助功能
    func promptAccessibilityGuide() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 检查所有需要的权限
    func checkAllPermissions() -> [AppPermissionType: Bool] {
        var result: [AppPermissionType: Bool] = [:]
        result[.accessibility] = isAccessibilityGranted()
        // 可扩展更多权限检测
        return result
    }

    /// 引导用户授权所有未授权的权限
    func promptAllMissingPermissions() {
        let permissions = checkAllPermissions()
        if permissions[.accessibility] == false {
            promptAccessibilityGuide()
        }
        // 可扩展更多权限引导
    }
}
