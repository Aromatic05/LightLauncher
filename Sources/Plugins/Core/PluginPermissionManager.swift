import Foundation

// MARK: - 插件权限类型
enum PluginPermission: String, CaseIterable, Codable {
    case network = "network"
    case fileWrite = "file_write"
    case systemCommand = "system_command"
    case clipboard = "clipboard"
    case notifications = "notifications"
    
    var displayName: String {
        switch self {
        case .network:
            return "网络访问"
        case .fileWrite:
            return "文件写入"
        case .systemCommand:
            return "系统命令执行"
        case .clipboard:
            return "剪贴板访问"
        case .notifications:
            return "通知权限"
        }
    }
    
    var description: String {
        switch self {
        case .network:
            return "允许插件访问网络，发起 HTTP/HTTPS 请求"
        case .fileWrite:
            return "允许插件写入文件到插件数据目录之外的位置"
        case .systemCommand:
            return "允许插件执行系统命令（高风险权限）"
        case .clipboard:
            return "允许插件读取和写入剪贴板内容"
        case .notifications:
            return "允许插件发送系统通知"
        }
    }
    
    var riskLevel: PluginPermissionRisk {
        switch self {
        case .network:
            return .medium
        case .fileWrite:
            return .low
        case .systemCommand:
            return .high
        case .clipboard:
            return .medium
        case .notifications:
            return .low
        }
    }
}

// MARK: - 权限风险级别
enum PluginPermissionRisk: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
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

// MARK: - 插件权限配置
struct PluginPermissionConfig: Codable {
    let pluginName: String
    let command: String
    var grantedPermissions: Set<PluginPermission>
    var deniedPermissions: Set<PluginPermission>
    var pendingPermissions: Set<PluginPermission>
    let createdAt: Date
    var updatedAt: Date
    
    init(pluginName: String, command: String) {
        self.pluginName = pluginName
        self.command = command
        self.grantedPermissions = []
        self.deniedPermissions = []
        self.pendingPermissions = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func grantPermission(_ permission: PluginPermission) {
        grantedPermissions.insert(permission)
        deniedPermissions.remove(permission)
        pendingPermissions.remove(permission)
        updatedAt = Date()
    }
    
    mutating func denyPermission(_ permission: PluginPermission) {
        deniedPermissions.insert(permission)
        grantedPermissions.remove(permission)
        pendingPermissions.remove(permission)
        updatedAt = Date()
    }
    
    mutating func requestPermission(_ permission: PluginPermission) {
        if !grantedPermissions.contains(permission) && !deniedPermissions.contains(permission) {
            pendingPermissions.insert(permission)
            updatedAt = Date()
        }
    }
    
    func hasPermission(_ permission: PluginPermission) -> Bool {
        return grantedPermissions.contains(permission)
    }
    
    func isPermissionDenied(_ permission: PluginPermission) -> Bool {
        return deniedPermissions.contains(permission)
    }
    
    func isPermissionPending(_ permission: PluginPermission) -> Bool {
        return pendingPermissions.contains(permission)
    }
}

// MARK: - 插件权限管理器
class PluginPermissionManager: ObservableObject, @unchecked Sendable {
    static let shared = PluginPermissionManager()
    
    @Published private(set) var pluginPermissions: [String: PluginPermissionConfig] = [:]
    @Published private(set) var pendingPermissionRequests: [PluginPermissionRequest] = []
    
    private let permissionsConfigPath: URL
    private let queue = DispatchQueue(label: "plugin.permissions", attributes: .concurrent)
    
    private init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        permissionsConfigPath = configDir.appendingPathComponent("plugin_permissions.json")
        
        loadPermissions()
    }
    
    // MARK: - 权限检查（线程安全）
    
    func hasPermission(pluginCommand: String, permission: PluginPermission) -> Bool {
        return queue.sync {
            guard let config = pluginPermissions[pluginCommand] else {
                return false
            }
            return config.hasPermission(permission)
        }
    }
    
    func checkNetworkPermission(for pluginCommand: String) -> Bool {
        return hasPermission(pluginCommand: pluginCommand, permission: .network)
    }
    
    func checkFileWritePermission(for pluginCommand: String) -> Bool {
        return hasPermission(pluginCommand: pluginCommand, permission: .fileWrite)
    }
    
    func checkSystemCommandPermission(for pluginCommand: String) -> Bool {
        return hasPermission(pluginCommand: pluginCommand, permission: .systemCommand)
    }
    
    // MARK: - 权限管理
    
    func requestPermission(pluginName: String, pluginCommand: String, permission: PluginPermission) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // 如果插件配置不存在，创建一个
            if self.pluginPermissions[pluginCommand] == nil {
                self.pluginPermissions[pluginCommand] = PluginPermissionConfig(pluginName: pluginName, command: pluginCommand)
            }
            
            guard var config = self.pluginPermissions[pluginCommand] else { return }
            
            // 如果权限已经被授予或拒绝，不需要再次请求
            if config.hasPermission(permission) || config.isPermissionDenied(permission) {
                return
            }
            
            // 添加到待处理权限请求
            config.requestPermission(permission)
            self.pluginPermissions[pluginCommand] = config
            
            let request = PluginPermissionRequest(
                pluginName: pluginName,
                pluginCommand: pluginCommand,
                permission: permission,
                requestedAt: Date()
            )
            
            DispatchQueue.main.async {
                self.pendingPermissionRequests.append(request)
                self.savePermissions()
            }
        }
    }
    
    func grantPermission(pluginCommand: String, permission: PluginPermission) {
        guard var config = pluginPermissions[pluginCommand] else { return }
        
        config.grantPermission(permission)
        pluginPermissions[pluginCommand] = config
        
        // 从待处理请求中移除
        pendingPermissionRequests.removeAll { request in
            request.pluginCommand == pluginCommand && request.permission == permission
        }
        
        savePermissions()
    }
    
    func denyPermission(pluginCommand: String, permission: PluginPermission) {
        guard var config = pluginPermissions[pluginCommand] else { return }
        
        config.denyPermission(permission)
        pluginPermissions[pluginCommand] = config
        
        // 从待处理请求中移除
        pendingPermissionRequests.removeAll { request in
            request.pluginCommand == pluginCommand && request.permission == permission
        }
        
        savePermissions()
    }
    
    func revokePermission(pluginCommand: String, permission: PluginPermission) {
        guard var config = pluginPermissions[pluginCommand] else { return }
        
        config.denyPermission(permission)
        pluginPermissions[pluginCommand] = config
        savePermissions()
    }
    
    func resetPluginPermissions(pluginCommand: String) {
        pluginPermissions[pluginCommand] = nil
        pendingPermissionRequests.removeAll { $0.pluginCommand == pluginCommand }
        savePermissions()
    }
    
    // MARK: - 配置管理
    
    func getPluginPermissionConfig(for pluginCommand: String) -> PluginPermissionConfig? {
        return pluginPermissions[pluginCommand]
    }
    
    func getAllPluginPermissions() -> [PluginPermissionConfig] {
        return Array(pluginPermissions.values)
    }
    
    // MARK: - 数据持久化
    
    private func loadPermissions() {
        guard FileManager.default.fileExists(atPath: permissionsConfigPath.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: permissionsConfigPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pluginPermissions = try decoder.decode([String: PluginPermissionConfig].self, from: data)
        } catch {
            print("Failed to load plugin permissions: \(error)")
        }
    }
    
    private func savePermissions() {
        do {
            // 确保目录存在
            let configDir = permissionsConfigPath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(pluginPermissions)
            try data.write(to: permissionsConfigPath)
        } catch {
            print("Failed to save plugin permissions: \(error)")
        }
    }
    
    /// 为插件初始化基本权限（自动授予低风险权限）
    func initializePluginPermissions(pluginName: String, pluginCommand: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // 如果插件配置不存在，创建一个
            if self.pluginPermissions[pluginCommand] == nil {
                var config = PluginPermissionConfig(pluginName: pluginName, command: pluginCommand)
                
                // 自动授予低风险权限
                for permission in PluginPermission.allCases {
                    if permission.riskLevel == .low {
                        config.grantPermission(permission)
                        print("Auto-granted \(permission.displayName) permission to plugin: \(pluginName)")
                    }
                }
                
                self.pluginPermissions[pluginCommand] = config
                
                DispatchQueue.main.async {
                    self.savePermissions()
                }
            }
        }
    }
}

// MARK: - 权限请求数据结构
struct PluginPermissionRequest: Identifiable {
    let id = UUID()
    let pluginName: String
    let pluginCommand: String
    let permission: PluginPermission
    let requestedAt: Date
}
