import Foundation
import Yams

// MARK: - 插件配置管理器
/// 负责所有插件配置文件的读写操作，包括全局注册表和个别插件配置
@MainActor
class PluginConfigManager {
    static let shared = PluginConfigManager()
    
    // MARK: - 路径常量
    private let baseConfigPath: URL
    private let pluginsPath: URL
    private let configsPath: URL
    private let dataPath: URL
    private let pluginsRegistryPath: URL
    
    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.baseConfigPath = homeDirectory.appendingPathComponent(".config/LightLauncher")
        self.pluginsPath = baseConfigPath.appendingPathComponent("plugins")
        self.configsPath = baseConfigPath.appendingPathComponent("configs")
        self.dataPath = baseConfigPath.appendingPathComponent("data")
        self.pluginsRegistryPath = baseConfigPath.appendingPathComponent("plugins.yaml")
        
        // 确保目录存在
        createDirectoriesIfNeeded()
    }
    
    // MARK: - 目录管理
    private func createDirectoriesIfNeeded() {
        let directories = [baseConfigPath, pluginsPath, configsPath, dataPath]
        for directory in directories {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - 插件注册表管理
    struct PluginRegistryEntry: Codable {
        let name: String
        var enabled: Bool
        let command: String
        let version: String
        let path: String
    }
    
    struct PluginRegistry: Codable {
        var plugins: [PluginRegistryEntry]
        
        init() {
            self.plugins = []
        }
    }
    
    /// 读取插件注册表
    func loadPluginRegistry() -> PluginRegistry {
        guard FileManager.default.fileExists(atPath: pluginsRegistryPath.path) else {
            return PluginRegistry()
        }
        
        do {
            let data = try Data(contentsOf: pluginsRegistryPath)
            let registry = try YAMLDecoder().decode(PluginRegistry.self, from: data)
            return registry
        } catch {
            print("读取插件注册表失败: \(error)")
            return PluginRegistry()
        }
    }
    
    /// 保存插件注册表
    func savePluginRegistry(_ registry: PluginRegistry) {
        do {
            let yamlString = try YAMLEncoder().encode(registry)
            try yamlString.write(to: pluginsRegistryPath, atomically: true, encoding: .utf8)
        } catch {
            print("保存插件注册表失败: \(error)")
        }
    }
    
    /// 注册新插件到注册表
    func registerPlugin(name: String, command: String, version: String, path: String, enabled: Bool = true) {
        var registry = loadPluginRegistry()
        
        // 检查是否已存在
        if let index = registry.plugins.firstIndex(where: { $0.name == name }) {
            // 更新现有插件
            registry.plugins[index] = PluginRegistryEntry(
                name: name,
                enabled: enabled,
                command: command,
                version: version,
                path: path
            )
        } else {
            // 添加新插件
            registry.plugins.append(PluginRegistryEntry(
                name: name,
                enabled: enabled,
                command: command,
                version: version,
                path: path
            ))
        }
        
        savePluginRegistry(registry)
    }
    
    /// 设置插件启用状态
    func setPluginEnabled(_ name: String, enabled: Bool) {
        var registry = loadPluginRegistry()
        if let index = registry.plugins.firstIndex(where: { $0.name == name }) {
            registry.plugins[index].enabled = enabled
            savePluginRegistry(registry)
        }
    }
    
    /// 获取已启用的插件列表
    func getEnabledPlugins() -> [PluginRegistryEntry] {
        return loadPluginRegistry().plugins.filter { $0.enabled }
    }
    
    // MARK: - 插件配置管理
    /// 读取插件的配置规范
    func loadConfigSpec(for pluginPath: URL) -> [String: Any]? {
        let configSpecPath = pluginPath.appendingPathComponent("config_spec.yaml")
        guard FileManager.default.fileExists(atPath: configSpecPath.path) else {
            return nil
        }
        
        do {
            let yamlString = try String(contentsOf: configSpecPath, encoding: .utf8)
            let configSpec = try Yams.load(yaml: yamlString) as? [String: Any]
            return configSpec
        } catch {
            print("读取配置规范失败 (\(pluginPath.lastPathComponent)): \(error)")
            return nil
        }
    }
    
    /// 读取插件的用户配置
    func loadUserConfig(for pluginName: String) -> [String: Any] {
        let configPath = configsPath.appendingPathComponent("\(pluginName).yaml")
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return [:]
        }
        
        do {
            let yamlString = try String(contentsOf: configPath, encoding: .utf8)
            let config = try Yams.load(yaml: yamlString) as? [String: Any] ?? [:]
            return config
        } catch {
            print("读取用户配置失败 (\(pluginName)): \(error)")
            return [:]
        }
    }
    
    /// 保存插件的用户配置
    func saveUserConfig(for pluginName: String, config: [String: Any]) {
        let configPath = configsPath.appendingPathComponent("\(pluginName).yaml")
        
        do {
            let yamlString = try Yams.dump(object: config)
            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
        } catch {
            print("保存用户配置失败 (\(pluginName)): \(error)")
        }
    }
    
    /// 合并默认配置和用户配置，生成最终生效的配置
    func getEffectiveConfig(for pluginName: String, pluginPath: URL) -> [String: Any] {
        var effectiveConfig: [String: Any] = [:]
        
        // 1. 加载配置规范中的默认值
        if let configSpec = loadConfigSpec(for: pluginPath),
           let fields = configSpec["fields"] as? [[String: Any]] {
            for field in fields {
                if let key = field["key"] as? String,
                   let defaultValue = field["default"] {
                    effectiveConfig[key] = defaultValue
                }
            }
        }
        
        // 2. 用用户配置覆盖默认值
        let userConfig = loadUserConfig(for: pluginName)
        for (key, value) in userConfig {
            effectiveConfig[key] = value
        }
        
        return effectiveConfig
    }
    
    // MARK: - 插件发现
    /// 扫描插件目录，发现新插件
    func discoverPlugins() -> [URL] {
        guard FileManager.default.fileExists(atPath: pluginsPath.path) else {
            return []
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: pluginsPath, includingPropertiesForKeys: nil)
            return contents.filter { url in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return isDirectory.boolValue && 
                       FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.yaml").path) &&
                       FileManager.default.fileExists(atPath: url.appendingPathComponent("index.js").path)
            }
        } catch {
            print("扫描插件目录失败: \(error)")
            return []
        }
    }
    
    // MARK: - 数据存储路径
    /// 获取插件的数据存储目录
    func getDataPath(for pluginName: String) -> URL {
        let pluginDataPath = dataPath.appendingPathComponent(pluginName)
        try? FileManager.default.createDirectory(at: pluginDataPath, withIntermediateDirectories: true)
        return pluginDataPath
    }
    
    // MARK: - 路径访问器
    var pluginsDirectory: URL { pluginsPath }
    var configsDirectory: URL { configsPath }
    var dataDirectory: URL { dataPath }
    
    // MARK: - 配置文件操作
    /// 获取插件配置文件路径
    func getConfigPath(for pluginName: String) -> URL {
        return configsPath.appendingPathComponent("\(pluginName).yaml")
    }
    
    /// 读取指定类型的配置
    func readConfig<T: Decodable>(for pluginName: String, type: T.Type) -> T? {
        let configPath = getConfigPath(for: pluginName)
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }
        
        do {
            let yamlString = try String(contentsOf: configPath, encoding: .utf8)
            return try YAMLDecoder().decode(T.self, from: yamlString)
        } catch {
            print("读取配置失败: \(error)")
            return nil
        }
    }
    
    /// 保存配置
    @discardableResult
    func saveConfig<T: Encodable>(_ config: T, for pluginName: String) -> Bool {
        let configPath = getConfigPath(for: pluginName)
        
        do {
            let yamlString = try YAMLEncoder().encode(config)
            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("保存配置失败: \(error)")
            return false
        }
    }
    
    /// 删除配置文件
    @discardableResult
    func deleteConfig(for pluginName: String) -> Bool {
        let configPath = getConfigPath(for: pluginName)
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return true // 文件不存在视为删除成功
        }
        
        do {
            try FileManager.default.removeItem(at: configPath)
            return true
        } catch {
            print("删除配置失败: \(error)")
            return false
        }
    }
    
    /// 创建默认配置
    @discardableResult
    func createDefaultConfig(for pluginName: String, config: PluginConfig) -> Bool {
        return saveConfig(config, for: pluginName)
    }
}
