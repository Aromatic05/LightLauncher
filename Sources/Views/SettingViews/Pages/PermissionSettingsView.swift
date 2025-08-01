import SwiftUI
import AppKit

// MARK: - 权限设置视图
struct PermissionSettingsView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var permissionSummary: AppPermissionSummary?
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("权限管理")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("管理应用所需的系统权限以确保功能正常运行")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let summary = permissionSummary {
                    // 权限状态概览
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.blue)
                            Text("权限状态概览")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // 状态卡片
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("授权完成度")
                                        .font(.headline)
                                    Text("\(summary.granted) / \(summary.totalRequired) 个必需权限已授权")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(Int(summary.completionPercentage * 100))%")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(summary.isFullyAuthorized ? .green : .orange)
                                    HStack(spacing: 4) {
                                        Image(systemName: summary.isFullyAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(summary.isFullyAuthorized ? .green : .orange)
                                            .font(.caption)
                                        Text(summary.isFullyAuthorized ? "已完成" : "未完成")
                                            .font(.caption)
                                            .foregroundColor(summary.isFullyAuthorized ? .green : .orange)
                                    }
                                }
                            }
                            
                            ProgressView(value: summary.completionPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: summary.isFullyAuthorized ? .green : .orange))
                                .scaleEffect(y: 2)
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // 权限详情列表
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.blue)
                            Text("权限详情")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 12) {
                            // 必需权限
                            let requiredPermissions = permissionManager.getRequiredPermissions()
                            if !requiredPermissions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("必需权限")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(requiredPermissions, id: \.rawValue) { permissionType in
                                        PermissionRowView(
                                            permissionType: permissionType,
                                            isGranted: summary.allPermissions[permissionType] == true,
                                            isRequired: true
                                        )
                                    }
                                }
                            }
                            
                            // 可选权限
                            let optionalPermissions = AppPermissionType.allCases.filter { !requiredPermissions.contains($0) }
                            if !optionalPermissions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("可选权限")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(optionalPermissions, id: \.rawValue) { permissionType in
                                        PermissionRowView(
                                            permissionType: permissionType,
                                            isGranted: summary.allPermissions[permissionType] == true,
                                            isRequired: false
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 操作按钮
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("权限管理操作")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 12) {
                            if !summary.isFullyAuthorized {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("批量授权缺失权限")
                                            .font(.headline)
                                        Text("一次性设置所有必需的权限")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("立即设置") {
                                        Task { @MainActor in
                                            permissionManager.promptAllMissingPermissions()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(16)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    refreshPermissionStatus()
                                }) {
                                    HStack(spacing: 6) {
                                        if isRefreshing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("刷新状态")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isRefreshing)
                                
                                Button("生成诊断报告") {
                                    copyDiagnosticsToClipboard()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("打开系统偏好设置") {
                                    openSystemPreferences()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 权限说明
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("权限说明")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PermissionInfoCard(
                                title: "高风险权限",
                                icon: "exclamationmark.shield",
                                iconColor: .red,
                                description: "这些权限提供对系统的深度访问，请谨慎授权",
                                examples: ["辅助功能", "完全磁盘访问", "输入监控"]
                            )
                            
                            PermissionInfoCard(
                                title: "中等风险权限",
                                icon: "shield.lefthalf.filled",
                                iconColor: .orange,
                                description: "这些权限访问特定功能，通常是安全的",
                                examples: ["自动化", "文件访问", "屏幕录制"]
                            )
                            
                            PermissionInfoCard(
                                title: "低风险权限",
                                icon: "shield",
                                iconColor: .green,
                                description: "这些权限对系统影响最小",
                                examples: ["网络访问", "通知权限"]
                            )
                        }
                    }
                } else {
                    // 加载状态
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在检查权限状态...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                
                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            refreshPermissionStatus()
        }
    }
    
    // MARK: - 辅助方法
    
    private func refreshPermissionStatus() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            permissionSummary = permissionManager.getPermissionSummary()
            isRefreshing = false
        }
    }
    
    private func copyDiagnosticsToClipboard() {
        let diagnostics = permissionManager.generatePermissionDiagnostics()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        
        // 显示成功提示
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "诊断报告已复制"
        alert.informativeText = "权限诊断报告已复制到剪贴板，您可以粘贴到文本编辑器中查看。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 权限行视图
struct PermissionRowView: View {
    let permissionType: AppPermissionType
    let isGranted: Bool
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.system(size: 20))
            
            // 权限信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(permissionType.rawValue)
                        .font(.system(size: 15, weight: .medium))
                    
                    if isRequired {
                        Text("必需")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    // 风险等级标识
                    Text(permissionType.riskLevel.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(permissionType.riskLevel.color).opacity(0.2))
                        .foregroundColor(Color(permissionType.riskLevel.color))
                        .cornerRadius(4)
                    
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
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isGranted ? 0.3 : 0.6))
        )
    }
}

// MARK: - 权限信息卡片
struct PermissionInfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    let examples: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("包括：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(examples.joined(separator: "、"))
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(10)
    }
}

// MARK: - 预览
struct PermissionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionSettingsView()
            .frame(width: 600, height: 800)
    }
}
