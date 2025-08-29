import Foundation

/// 插件权限管理器 - 负责插件权限的校验和管理
@MainActor
class PluginPermissionManager {
    static let shared = PluginPermissionManager()

    private init() {}

    /// 检查插件是否具有指定权限
    /// - Parameters:
    ///   - plugin: 插件对象
    ///   - type: 权限类型
    /// - Returns: 是否具有权限
    func hasPermission(plugin: Plugin, type: PluginPermissionType) -> Bool {
        guard let permissions = plugin.manifest.permissions else {
            return false
        }

        return permissions.contains { $0.type == type }
    }

    /// 检查插件是否具有指定目录的文件权限
    /// - Parameters:
    ///   - plugin: 插件对象
    ///   - type: 权限类型（fileRead 或 fileWrite）
    ///   - path: 文件路径
    /// - Returns: 是否具有权限
    func hasFilePermission(plugin: Plugin, type: PluginPermissionType, path: String) -> Bool {
        guard type == .fileRead || type == .fileWrite else {
            return false
        }

        guard let permissions = plugin.manifest.permissions else {
            return false
        }

        // 查找对应的权限配置
        guard let permission = permissions.first(where: { $0.type == type }) else {
            return false
        }

        // 如果没有指定目录限制，则允许访问所有目录
        guard let allowedDirectories = permission.directories, !allowedDirectories.isEmpty else {
            return true
        }

        // 检查路径是否在允许的目录中
        return allowedDirectories.contains { allowedDir in
            path.hasPrefix(allowedDir)
        }
    }

    /// 验证插件的所有权限声明是否有效
    /// - Parameter plugin: 插件对象
    /// - Returns: 验证结果
    func validatePermissions(for plugin: Plugin) -> PermissionValidationResult {
        guard let permissions = plugin.manifest.permissions else {
            return .valid
        }

        var issues: [String] = []

        for permission in permissions {
            // 验证权限类型是否有效
            if !PluginPermissionType.allCases.contains(permission.type) {
                issues.append("未知的权限类型: \(permission.type.rawValue)")
                continue
            }

            // 验证目录权限的配置
            if permission.type == .fileRead || permission.type == .fileWrite {
                if let directories = permission.directories {
                    for directory in directories {
                        if !isValidDirectoryPath(directory) {
                            issues.append("无效的目录路径: \(directory)")
                        }
                    }
                }
            }
        }

        return issues.isEmpty ? .valid : .invalid(issues)
    }

    /// 获取插件的权限摘要
    /// - Parameter plugin: 插件对象
    /// - Returns: 权限摘要
    func getPermissionSummary(for plugin: Plugin) -> PermissionSummary {
        guard let permissions = plugin.manifest.permissions else {
            return PermissionSummary(permissions: [], riskLevel: .low)
        }

        let permissionDescriptions = permissions.map { permission in
            PermissionDescription(
                type: permission.type,
                description: getPermissionDescription(permission.type),
                directories: permission.directories
            )
        }

        let riskLevel = calculateRiskLevel(permissions: permissions)

        return PermissionSummary(permissions: permissionDescriptions, riskLevel: riskLevel)
    }

    // MARK: - 私有方法

    private func isValidDirectoryPath(_ path: String) -> Bool {
        // 基本的路径验证
        return !path.isEmpty && !path.contains("..") && path.hasPrefix("/")
    }

    private func getPermissionDescription(_ type: PluginPermissionType) -> String {
        switch type {
        case .network:
            return "访问网络，发送HTTP请求"
        case .fileWrite:
            return "写入文件到指定目录"
        case .fileRead:
            return "读取指定目录中的文件"
        case .systemCommand:
            return "执行系统命令"
        case .clipboard:
            return "访问系统剪贴板"
        case .notifications:
            return "显示系统通知"
        }
    }

    private func calculateRiskLevel(permissions: [PluginPermissionSpec]) -> RiskLevel {
        let highRiskPermissions: Set<PluginPermissionType> = [.systemCommand, .fileWrite]
        let mediumRiskPermissions: Set<PluginPermissionType> = [.network, .fileRead]

        let permissionTypes = Set(permissions.map { $0.type })

        if !permissionTypes.isDisjoint(with: highRiskPermissions) {
            return .high
        } else if !permissionTypes.isDisjoint(with: mediumRiskPermissions) {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - 数据结构

enum PermissionValidationResult {
    case valid
    case invalid([String])
}

struct PermissionSummary {
    let permissions: [PermissionDescription]
    let riskLevel: RiskLevel
}

struct PermissionDescription {
    let type: PluginPermissionType
    let description: String
    let directories: [String]?
}

enum RiskLevel {
    case low
    case medium
    case high

    var description: String {
        switch self {
        case .low:
            return "低风险"
        case .medium:
            return "中等风险"
        case .high:
            return "高风险"
        }
    }

    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        }
    }
}
