//
//  PermissionManager+Usage.swift
//  LightLauncher
//
//  权限管理器使用示例和集成指南

import Foundation
import AppKit

/*
 
 权限管理器集成指南
 ==================
 
 1. 在 AppDelegate 中进行启动权限检查：
 
 ```swift
 func applicationDidFinishLaunching(_ aNotification: Notification) {
     // 其他启动代码...
     
     // 权限检查
     Task { @MainActor in
         PermissionManager.shared.performStartupPermissionCheck()
     }
 }
 ```
 
 2. 在浏览器数据管理器中添加权限检查：
 
 ```swift
 // 在 BrowserDataManager.swift 的 loadBrowserData() 方法中
 func loadBrowserData() {
     PermissionManager.shared.withBrowserDataPermission {
         // 原有的浏览器数据加载逻辑
         if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 { return }
         
         Task.detached(priority: .utility) {
             // 现有的数据加载代码...
         }
     }
 }
 ```
 
 3. 在进程管理模式中添加权限检查：
 
 ```swift
 // 在 KillModeController.swift 的 executeAction 方法中
 func executeAction(at index: Int) -> Bool {
     PermissionManager.shared.withProcessManagementPermission {
         // 原有的进程结束逻辑
         let items = self.displayableItems
         guard index < items.count else { return false }
         
         if let runningApp = items[index] as? RunningApp {
             // 现有的应用结束代码...
         }
     }
     return false
 }
 ```
 
 4. 在全局快捷键设置中添加权限检查：
 
 ```swift
 // 在 KeyboardEventHandler.swift 或相关的快捷键处理代码中
 func setupGlobalHotKey() {
     PermissionManager.shared.withGlobalHotKeyPermission {
         // 原有的快捷键设置逻辑
         self.registerGlobalHotKey()
     }
 }
 ```
 
 5. 在设置界面中添加权限管理页面：
 
 在设置视图中添加权限状态显示和管理功能。
 
 */

// MARK: - 在设置界面中显示权限状态的 SwiftUI 视图示例

import SwiftUI

struct PermissionsSettingsView: View {
    private var permissionManager = PermissionManager.shared
    @State private var permissionSummary: AppPermissionSummary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                Text("权限管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let summary = permissionSummary {
                // 权限状态概览
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("权限状态")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(summary.completionPercentage * 100))%")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(summary.isFullyAuthorized ? .green : .orange)
                    }
                    
                    ProgressView(value: summary.completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: summary.isFullyAuthorized ? .green : .orange))
                    
                    Text("\(summary.granted) / \(summary.totalRequired) 个必需权限已授权")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                
                // 权限详情列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("权限详情")
                        .font(.headline)
                    
                    ForEach(AppPermissionType.allCases, id: \.rawValue) { permissionType in
                        PermissionRowView(
                            permissionType: permissionType,
                            isGranted: summary.allPermissions[permissionType] == true,
                            isRequired: permissionManager.getRequiredPermissions().contains(permissionType)
                        )
                    }
                }
                
                // 操作按钮
                HStack(spacing: 12) {
                    if !summary.isFullyAuthorized {
                        Button("授权缺失权限") {
                            Task { @MainActor in
                                permissionManager.promptAllMissingPermissions()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("刷新状态") {
                        refreshPermissionStatus()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("生成诊断报告") {
                        copyDiagnosticsToClipboard()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
            }
        }
        .padding()
        .onAppear {
            refreshPermissionStatus()
        }
    }
    
    private func refreshPermissionStatus() {
        permissionSummary = permissionManager.getPermissionSummary()
    }
    
    private func copyDiagnosticsToClipboard() {
        let diagnostics = permissionManager.generatePermissionDiagnostics()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        
        // 可以添加一个临时通知显示复制成功
    }
}

struct PermissionRowView: View {
    let permissionType: AppPermissionType
    let isGranted: Bool
    let isRequired: Bool
    
    var body: some View {
        HStack {
            // 状态图标
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.system(size: 16))
            
            // 权限信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(permissionType.rawValue)
                        .font(.system(size: 14, weight: .medium))
                    
                    if isRequired {
                        Text("必需")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text(permissionType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 操作按钮
            if !isGranted {
                Button("设置") {
                    Task { @MainActor in
                        PermissionManager.shared.promptPermissionGuide(for: permissionType)
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isGranted ? 0.3 : 0.6))
        )
    }
}

// MARK: - 预览
struct PermissionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSettingsView()
            .frame(width: 500, height: 600)
    }
}
