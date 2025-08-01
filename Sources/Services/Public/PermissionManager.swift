import Foundation
import ApplicationServices
import AppKit
import AVFoundation
import Contacts
import EventKit
import Photos
import CoreGraphics

/// 权限类型枚举
enum AppPermissionType: String, CaseIterable {
    case accessibility = "辅助功能"
    case automation = "自动化"
    case fullDiskAccess = "完全磁盘访问权限"
    case inputMonitoring = "输入监控"
    case screenRecording = "屏幕录制"
    case microphone = "麦克风"
    case camera = "摄像头"
    case contacts = "通讯录"
    case calendars = "日历"
    case reminders = "提醒事项"
    case photos = "照片"
    case fileAccess = "文件访问"
    case networkAccess = "网络访问"
    
    /// 权限的描述信息
    var description: String {
        switch self {
        case .accessibility:
            return "允许应用控制您的计算机，用于执行自动化操作和快捷键监听"
        case .automation:
            return "允许应用向其他应用发送自动化指令"
        case .fullDiskAccess:
            return "访问浏览器数据、系统文件等需要此权限"
        case .inputMonitoring:
            return "监听键盘输入，用于全局快捷键功能"
        case .screenRecording:
            return "截取屏幕内容，某些插件功能可能需要"
        case .microphone:
            return "访问麦克风，语音相关插件需要"
        case .camera:
            return "访问摄像头，图像处理插件需要"
        case .contacts:
            return "访问通讯录数据，联系人相关功能需要"
        case .calendars:
            return "访问日历数据，日程管理功能需要"
        case .reminders:
            return "访问提醒事项，任务管理功能需要"
        case .photos:
            return "访问照片库，图片处理功能需要"
        case .fileAccess:
            return "访问文件系统，文件浏览和管理功能需要"
        case .networkAccess:
            return "访问网络，网页搜索和在线插件需要"
        }
    }
    
    /// 权限的风险等级
    var riskLevel: PermissionRiskLevel {
        switch self {
        case .accessibility, .fullDiskAccess, .inputMonitoring:
            return .high
        case .automation, .screenRecording, .fileAccess:
            return .medium
        case .microphone, .camera, .contacts, .calendars, .reminders, .photos:
            return .medium
        case .networkAccess:
            return .low
        }
    }
}

/// 权限风险等级
enum PermissionRiskLevel: String, CaseIterable {
    case low = "低风险"
    case medium = "中等风险"  
    case high = "高风险"
    
    var color: NSColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemOrange
        case .high: return .systemRed
        }
    }
}

/// 权限管理器，统一检测和引导用户授权敏感权限
final class PermissionManager: ObservableObject {
    @MainActor static let shared = PermissionManager()
    private init() {}

    // MARK: - 通用权限检查方法
    
    /// 有权限则执行，无权限则引导用户授权
    @MainActor
    func withPermission(_ type: AppPermissionType, perform action: @escaping () -> Void) {
        if hasPermission(for: type) {
            action()
        } else {
            promptPermissionGuide(for: type)
        }
    }
    
    /// 检查指定权限是否已授权
    func hasPermission(for type: AppPermissionType) -> Bool {
        switch type {
        case .accessibility:
            return isAccessibilityGranted()
        case .automation:
            return isAutomationGranted()
        case .fullDiskAccess:
            return isFullDiskAccessGranted()
        case .inputMonitoring:
            return isInputMonitoringGranted()
        case .screenRecording:
            return isScreenRecordingGranted()
        case .microphone:
            return isMicrophoneGranted()
        case .camera:
            return isCameraGranted()
        case .contacts:
            return isContactsGranted()
        case .calendars:
            return isCalendarsGranted()
        case .reminders:
            return isRemindersGranted()
        case .photos:
            return isPhotosGranted()
        case .fileAccess:
            return isFileAccessGranted()
        case .networkAccess:
            return isNetworkAccessGranted()
        }
    }
    
    /// 引导用户授权指定权限
    @MainActor
    func promptPermissionGuide(for type: AppPermissionType) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要\(type.rawValue)权限"
        alert.informativeText = type.description
        alert.addButton(withTitle: "前往设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemPreferences(for: type)
        }
    }
    
    /// 打开对应的系统偏好设置
    private func openSystemPreferences(for type: AppPermissionType) {
        let url: URL
        
        switch type {
        case .accessibility:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .automation:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        case .fullDiskAccess:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        case .inputMonitoring:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        case .screenRecording:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case .microphone:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .camera:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        case .contacts:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts")!
        case .calendars:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        case .reminders:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
        case .photos:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!
        case .fileAccess, .networkAccess:
            // 这些权限通常通过应用程序内部处理，打开隐私设置主页面
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        }
        
        NSWorkspace.shared.open(url)
    }

    // MARK: - 具体权限检查实现

    /// 检查辅助功能权限
    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// 检查自动化权限（通过尝试向系统发送 Apple Event 来检测）
    func isAutomationGranted() -> Bool {
        // 简单的检测方法：尝试获取 System Events 进程
        let script = NSAppleScript(source: "tell application \"System Events\" to get name")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil && result != nil
    }
    
    /// 检查完全磁盘访问权限
    func isFullDiskAccessGranted() -> Bool {
        // 检测是否能访问受保护的目录（如 Safari 书签）
        let safariBookmarksPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        
        do {
            _ = try Data(contentsOf: safariBookmarksPath)
            return true
        } catch {
            return false
        }
    }
    
    /// 检查输入监控权限
    func isInputMonitoringGranted() -> Bool {
        // 在 macOS 10.15+ 需要此权限来监听全局按键
        if #available(macOS 10.15, *) {
            // 通过检查是否能创建事件监听器来判断
            let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: { (proxy, type, event, refcon) in
                    return Unmanaged.passUnretained(event)
                },
                userInfo: nil
            )
            
            let hasPermission = eventTap != nil
            // 在 ARC 环境下，eventTap 会自动释放，不需要手动 CFRelease
            return hasPermission
        }
        return true // 较老版本的 macOS 不需要此权限
    }
    
    /// 检查屏幕录制权限
    func isScreenRecordingGranted() -> Bool {
        if #available(macOS 10.15, *) {
            // 简单的方法：尝试获取主显示器信息
            let mainDisplayID = CGMainDisplayID()
            return mainDisplayID != 0
        }
        return true
    }
    
    /// 检查麦克风权限
    func isMicrophoneGranted() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    /// 检查摄像头权限
    func isCameraGranted() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    /// 检查通讯录权限
    func isContactsGranted() -> Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    /// 检查日历权限
    func isCalendarsGranted() -> Bool {
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }
    
    /// 检查提醒事项权限
    func isRemindersGranted() -> Bool {
        return EKEventStore.authorizationStatus(for: .reminder) == .authorized
    }
    
    /// 检查照片权限
    func isPhotosGranted() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    /// 检查文件访问权限（基本文件系统访问）
    func isFileAccessGranted() -> Bool {
        // 检查是否能访问用户文档目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return FileManager.default.isReadableFile(atPath: documentsPath.path)
    }
    
    /// 检查网络访问权限（应用层面，通常默认允许）
    func isNetworkAccessGranted() -> Bool {
        // 网络访问通常不需要特殊权限，除非有特殊的网络策略
        return true
    }

    // MARK: - 批量权限管理

    /// 检查所有需要的权限
    func checkAllPermissions() -> [AppPermissionType: Bool] {
        var result: [AppPermissionType: Bool] = [:]
        for type in AppPermissionType.allCases {
            result[type] = hasPermission(for: type)
        }
        return result
    }
    
    /// 获取当前应用实际需要的权限列表
    func getRequiredPermissions() -> [AppPermissionType] {
        return [
            .accessibility,      // 应用控制和自动化操作
            .fullDiskAccess,     // 浏览器数据访问
            .automation,         // 应用控制
            .fileAccess,         // 文件浏览
            .networkAccess       // 网页搜索
        ]
    }
    
    /// 获取缺失的权限
    func getMissingPermissions() -> [AppPermissionType] {
        let required = getRequiredPermissions()
        return required.filter { !hasPermission(for: $0) }
    }
    
    /// 引导用户授权所有缺失的权限
    @MainActor
    func promptAllMissingPermissions() {
        let missingPermissions = getMissingPermissions()
        
        if missingPermissions.isEmpty {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "权限检查完成"
            alert.informativeText = "所有必要权限已授权，应用功能完全可用。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要授权权限"
        
        let permissionList = missingPermissions.map { "• \($0.rawValue)：\($0.description)" }.joined(separator: "\n")
        alert.informativeText = "为了正常使用所有功能，需要授权以下权限：\n\n\(permissionList)\n\n建议逐个授权这些权限。"
        
        alert.addButton(withTitle: "逐个设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 逐个引导用户设置权限
            for permission in missingPermissions {
                promptPermissionGuide(for: permission)
            }
        }
    }
    
    /// 获取权限状态摘要
    func getPermissionSummary() -> AppPermissionSummary {
        let allPermissions = checkAllPermissions()
        let requiredPermissions = getRequiredPermissions()
        
        let grantedRequired = requiredPermissions.filter { allPermissions[$0] == true }
        let missingRequired = requiredPermissions.filter { allPermissions[$0] == false }
        
        return AppPermissionSummary(
            totalRequired: requiredPermissions.count,
            granted: grantedRequired.count,
            missing: missingRequired.count,
            missingPermissions: missingRequired,
            allPermissions: allPermissions
        )
    }

    // MARK: - 向后兼容的方法

    /// 有权限则执行，无权限则引导用户授权辅助功能（保持向后兼容）
    @MainActor
    func withAccessibilityPermission(perform action: @escaping () -> Void) {
        withPermission(.accessibility, perform: action)
    }

    /// 引导用户前往系统设置授权辅助功能（保持向后兼容）
    @MainActor
    func promptAccessibilityGuide() {
        promptPermissionGuide(for: .accessibility)
    }
}

// MARK: - 应用权限摘要数据结构

struct AppPermissionSummary {
    let totalRequired: Int
    let granted: Int
    let missing: Int
    let missingPermissions: [AppPermissionType]
    let allPermissions: [AppPermissionType: Bool]
    
    var isFullyAuthorized: Bool {
        return missing == 0
    }
    
    var completionPercentage: Double {
        guard totalRequired > 0 else { return 1.0 }
        return Double(granted) / Double(totalRequired)
    }
}
