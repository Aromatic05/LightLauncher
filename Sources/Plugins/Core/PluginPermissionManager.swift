import Foundation

// MARK: - 插件权限类型（带参数）
enum PluginPermissionType: String, CaseIterable, Codable {
    case network = "network"
    case fileWrite = "file_write"
    case fileRead = "file_read"
    case systemCommand = "system_command"
    case clipboard = "clipboard"
    case notifications = "notifications"
}

struct PluginPermissionSpec: Codable, Hashable {
    let type: PluginPermissionType
    let directories: [String]?
    // 只有 fileWrite/fileRead 需要 directories，其它为 nil
    
    init(type: PluginPermissionType, directories: [String]? = nil) {
        self.type = type
        self.directories = directories
    }
}

// MARK: - 插件权限配置
struct PluginPermissionConfig: Codable {
    let pluginName: String
    let command: String
    let permissions: [PluginPermissionSpec]
    let pluginDirectory: String // 新增字段，插件根目录
    let createdAt: Date
    var updatedAt: Date
    
    init(pluginName: String, command: String, permissions: [PluginPermissionSpec], pluginDirectory: String) {
        self.pluginName = pluginName
        self.command = command
        self.permissions = permissions
        self.pluginDirectory = pluginDirectory
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func hasPermission(_ type: PluginPermissionType, directory: String? = nil) -> Bool {
        // 插件自己的目录始终有读写权限
        if let dir = directory, (type == .fileRead || type == .fileWrite) {
            if dir.hasPrefix(pluginDirectory) {
                return true
            }
        }
        for perm in permissions {
            if perm.type == type {
                if let dirs = perm.directories, let dir = directory {
                    // 只要有一个目录前缀匹配即可
                    if dirs.contains(where: { dir.hasPrefix($0) }) {
                        return true
                    }
                } else if perm.directories == nil {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - 插件权限管理器
class PluginPermissionManager: ObservableObject, @unchecked Sendable {
    static let shared = PluginPermissionManager()
    
    @Published private(set) var pluginPermissions: [String: PluginPermissionConfig] = [:]
    
    private let permissionsConfigPath: URL
    private let queue = DispatchQueue(label: "plugin.permissions", attributes: .concurrent)
    
    private init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        permissionsConfigPath = configDir.appendingPathComponent("plugin_permissions.json")
        loadPermissions()
    }
    
    // MARK: - 权限检查（线程安全）
    func hasPermission(pluginCommand: String, type: PluginPermissionType, directory: String? = nil) -> Bool {
        return queue.sync {
            guard let config = pluginPermissions[pluginCommand] else {
                return false
            }
            return config.hasPermission(type, directory: directory)
        }
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
    
    /// 由插件 manifest 初始化权限
    func initializePluginPermissions(pluginName: String, pluginCommand: String, permissions: [PluginPermissionSpec], pluginDirectory: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.pluginPermissions[pluginCommand] == nil {
                let config = PluginPermissionConfig(pluginName: pluginName, command: pluginCommand, permissions: permissions, pluginDirectory: pluginDirectory)
                self.pluginPermissions[pluginCommand] = config
                DispatchQueue.main.async {
                    self.savePermissions()
                }
            }
        }
    }
}
