# LightLauncher 权限管理器

## 概述

LightLauncher 权限管理器是一个全面的 macOS 权限管理解决方案，专门为启动器应用的各种功能提供权限检查、引导和管理功能。

## 支持的权限类型

### 必需权限（核心功能）

1. **辅助功能 (Accessibility)**
   - 用途：全局快捷键监听、应用控制、自动化操作
   - 风险等级：高
   - 需要功能：快捷键响应、应用启动控制

2. **完全磁盘访问 (Full Disk Access)**
   - 用途：访问浏览器书签和历史记录文件
   - 风险等级：高
   - 需要功能：浏览器数据读取（Safari、Chrome、Firefox、Edge、Arc）

3. **输入监控 (Input Monitoring)**
   - 用途：全局键盘事件监听
   - 风险等级：高
   - 需要功能：全局快捷键检测

4. **自动化 (Automation)**
   - 用途：向其他应用发送控制指令
   - 风险等级：中等
   - 需要功能：应用进程管理、应用启动

5. **文件访问 (File Access)**
   - 用途：文件系统浏览和访问
   - 风险等级：中等
   - 需要功能：文件浏览器模式

6. **网络访问 (Network Access)**
   - 用途：网页搜索、在线插件功能
   - 风险等级：低
   - 需要功能：搜索引擎查询、插件网络请求

### 可选权限（插件扩展）

7. **屏幕录制 (Screen Recording)**
   - 用途：截图相关插件功能
   - 风险等级：中等

8. **麦克风 (Microphone)**
   - 用途：语音识别插件
   - 风险等级：中等

9. **摄像头 (Camera)**
   - 用途：图像处理插件
   - 风险等级：中等

10. **通讯录 (Contacts)**
    - 用途：联系人搜索功能
    - 风险等级：中等

11. **日历 (Calendars)**
    - 用途：日程管理插件
    - 风险等级：中等

12. **提醒事项 (Reminders)**
    - 用途：任务管理插件
    - 风险等级：中等

13. **照片 (Photos)**
    - 用途：图片搜索和处理
    - 风险等级：中等

## 主要功能

### 权限检查
```swift
// 检查单个权限
let hasAccess = PermissionManager.shared.hasPermission(for: .accessibility)

// 检查所有权限
let allPermissions = PermissionManager.shared.checkAllPermissions()

// 检查特定功能权限
let canAccessBrowserData = PermissionManager.shared.checkBrowserDataPermissions()
```

### 权限引导
```swift
// 引导单个权限
PermissionManager.shared.promptPermissionGuide(for: .fullDiskAccess)

// 引导所有缺失权限
PermissionManager.shared.promptAllMissingPermissions()
```

### 安全执行包装器
```swift
// 安全执行需要权限的操作
PermissionManager.shared.withBrowserDataPermission {
    // 浏览器数据加载逻辑
}

PermissionManager.shared.withProcessManagementPermission {
    // 进程管理逻辑
}
```

### 权限状态摘要
```swift
let summary = PermissionManager.shared.getPermissionSummary()
print("权限完成度：\(Int(summary.completionPercentage * 100))%")
print("缺失权限：\(summary.missingPermissions)")
```

## 集成指南

### 1. 应用启动时检查
在 `AppDelegate.swift` 中添加：
```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    Task { @MainActor in
        PermissionManager.shared.performStartupPermissionCheck()
    }
}
```

### 2. 功能使用前检查
在各个功能模块中，使用权限包装器确保安全执行：

**浏览器数据加载：**
```swift
// BrowserDataManager.swift
func loadBrowserData() {
    PermissionManager.shared.withBrowserDataPermission {
        // 现有的数据加载逻辑
    }
}
```

**进程管理：**
```swift
// KillModeController.swift
func executeAction(at index: Int) -> Bool {
    var result = false
    PermissionManager.shared.withProcessManagementPermission {
        // 现有的进程结束逻辑
        result = self.killProcess(at: index)
    }
    return result
}
```

**全局快捷键：**
```swift
// KeyboardEventHandler.swift
func setupGlobalHotKey() {
    PermissionManager.shared.withGlobalHotKeyPermission {
        // 现有的快捷键设置逻辑
    }
}
```

### 3. 设置界面集成
在设置界面中添加权限管理页面，使用提供的 `PermissionsSettingsView`。

## 调试和诊断

### 生成诊断报告
```swift
let report = PermissionManager.shared.generatePermissionDiagnostics()
print(report)
```

### 控制台输出
```swift
PermissionManager.shared.printPermissionDiagnostics()
```

## 最佳实践

1. **渐进式权限请求**：不要在启动时一次性请求所有权限，根据用户使用功能时再请求相应权限。

2. **明确的权限说明**：为每个权限提供清晰的用途说明，让用户了解为什么需要这些权限。

3. **优雅的降级**：当权限不足时，提供替代方案或清晰的提示，而不是直接失败。

4. **定期检查**：在关键功能执行前检查权限状态，因为用户可能在使用过程中撤销权限。

5. **用户友好的引导**：提供直接跳转到系统设置的便捷方式，减少用户手动查找的麻烦。

## 注意事项

- macOS 权限系统在不同版本间可能有差异，代码中已经做了版本兼容性处理
- 某些权限（如完全磁盘访问）需要应用重启才能生效
- 权限检查可能有性能开销，建议在适当时机进行缓存
- 开发和调试时，可能需要在系统设置中手动重置权限进行测试

## 文件结构

```
Sources/Services/
├── PermissionManager.swift              # 核心权限管理器
├── PermissionManager+Integration.swift  # 集成扩展和便利方法
└── PermissionManager+Usage.swift        # 使用示例和SwiftUI视图
```

这个权限管理器为 LightLauncher 提供了全面的权限管理能力，确保各项功能能够安全、可靠地运行，同时为用户提供清晰的权限控制和管理界面。
