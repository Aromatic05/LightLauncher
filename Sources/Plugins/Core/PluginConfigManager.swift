import Foundation
import Yams

/// 插件配置管理器 - 负责插件配置的读取、保存和管理
@MainActor
class PluginConfigManager {
    static let shared = PluginConfigManager()

    private let configDirectory: URL
    private var configCache: [String: PluginConfig] = [:]

    private init() {
        // 创建配置目录
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        configDirectory = appSupport.appendingPathComponent("LightLauncher/configs")

        // 确保配置目录存在
        try? FileManager.default.createDirectory(
            at: configDirectory, withIntermediateDirectories: true)
    }

    /// 为插件确保配置文件存在
    /// - Parameter plugin: 插件对象
    func ensureConfigExists(for plugin: Plugin) {
        let configPath = getConfigPath(for: plugin.name)

        // 如果配置文件不存在，创建默认配置
        if !FileManager.default.fileExists(atPath: configPath.path) {
            createDefaultConfig(for: plugin)
        }
    }

    /// 读取插件配置
    /// - Parameter pluginName: 插件名称
    /// - Returns: 插件配置，如果不存在则返回默认配置
    func loadConfig(for pluginName: String) -> PluginConfig {
        // 先检查缓存
        if let cachedConfig = configCache[pluginName] {
            return cachedConfig
        }

        let configPath = getConfigPath(for: pluginName)

        do {
            let configData = try Data(contentsOf: configPath)
            let configString = String(data: configData, encoding: .utf8) ?? ""

            let yaml = try Yams.load(yaml: configString)
            let config = parseConfig(from: yaml)

            // 缓存配置
            configCache[pluginName] = config

            return config
        } catch {
            print("加载插件配置失败 (\(pluginName)): \(error.localizedDescription)")

            // 返回默认配置
            let defaultConfig = PluginConfig()
            configCache[pluginName] = defaultConfig
            return defaultConfig
        }
    }

    /// 保存插件配置
    /// - Parameters:
    ///   - config: 配置对象
    ///   - pluginName: 插件名称
    /// - Returns: 是否保存成功
    func saveConfig(_ config: PluginConfig, for pluginName: String) -> Bool {
        let configPath = getConfigPath(for: pluginName)

        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)

            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)

            // 更新缓存
            configCache[pluginName] = config

            print("插件配置已保存: \(pluginName)")
            return true
        } catch {
            print("保存插件配置失败 (\(pluginName)): \(error.localizedDescription)")
            return false
        }
    }

    /// 获取配置值
    /// - Parameters:
    ///   - key: 配置键
    ///   - pluginName: 插件名称
    /// - Returns: 配置值
    func getValue<T>(for key: String, in pluginName: String, as type: T.Type) -> T? {
        let config = loadConfig(for: pluginName)

        guard let configValue = config.settings[key] else {
            return nil
        }

        return configValue.value as? T
    }

    /// 设置配置值
    /// - Parameters:
    ///   - key: 配置键
    ///   - value: 配置值
    ///   - pluginName: 插件名称
    ///   - description: 配置描述（可选）
    /// - Returns: 是否设置成功
    func setValue<T>(_ value: T, for key: String, in pluginName: String, description: String? = nil)
        -> Bool
    {
        var config = loadConfig(for: pluginName)

        let typeString: String
        switch value {
        case is String:
            typeString = "string"
        case is Bool:
            typeString = "boolean"
        case is Double, is Int:
            typeString = "number"
        default:
            typeString = "string"
        }

        config.settings[key] = ConfigValue(type: typeString, value: value, description: description)

        return saveConfig(config, for: pluginName)
    }

    /// 删除配置项
    /// - Parameters:
    ///   - key: 配置键
    ///   - pluginName: 插件名称
    /// - Returns: 是否删除成功
    func removeValue(for key: String, in pluginName: String) -> Bool {
        var config = loadConfig(for: pluginName)
        config.settings.removeValue(forKey: key)
        return saveConfig(config, for: pluginName)
    }

    /// 重置插件配置为默认值
    /// - Parameter pluginName: 插件名称
    /// - Returns: 是否重置成功
    func resetConfig(for pluginName: String) -> Bool {
        let defaultConfig = PluginConfig()
        configCache.removeValue(forKey: pluginName)
        return saveConfig(defaultConfig, for: pluginName)
    }

    /// 删除插件配置文件
    /// - Parameter pluginName: 插件名称
    /// - Returns: 是否删除成功
    func deleteConfig(for pluginName: String) -> Bool {
        let configPath = getConfigPath(for: pluginName)

        do {
            try FileManager.default.removeItem(at: configPath)
            configCache.removeValue(forKey: pluginName)
            print("插件配置已删除: \(pluginName)")
            return true
        } catch {
            print("删除插件配置失败 (\(pluginName)): \(error.localizedDescription)")
            return false
        }
    }

    /// 获取所有配置文件列表
    /// - Returns: 配置文件名数组
    func getAllConfigNames() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: configDirectory,
                includingPropertiesForKeys: nil)
            return
                contents
                .filter { $0.pathExtension == "yaml" }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            print("获取配置文件列表失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 清空配置缓存
    func clearCache() {
        configCache.removeAll()
    }

    // MARK: - 私有方法

    func getConfigPath(for pluginName: String) -> URL {
        return configDirectory.appendingPathComponent("\(pluginName).yaml")
    }

    private func createDefaultConfig(for plugin: Plugin) {
        let defaultConfig = PluginConfig()
        _ = saveConfig(defaultConfig, for: plugin.name)
        print("为插件 \(plugin.name) 创建了默认配置")
    }

    private func parseConfig(from yaml: Any?) -> PluginConfig {
        guard let yamlDict = yaml as? [String: Any] else {
            return PluginConfig()
        }

        guard let settingsDict = yamlDict["settings"] as? [String: Any] else {
            return PluginConfig()
        }

        var settings: [String: ConfigValue] = [:]

        for (key, value) in settingsDict {
            if let configDict = value as? [String: Any],
                let type = configDict["type"] as? String,
                let configValue = configDict["value"]
            {

                let description = configDict["description"] as? String
                settings[key] = ConfigValue(
                    type: type, value: configValue, description: description)
            } else {
                // 简单值，推断类型
                let typeString: String
                switch value {
                case is String:
                    typeString = "string"
                case is Bool:
                    typeString = "boolean"
                case is Double, is Int:
                    typeString = "number"
                default:
                    typeString = "string"
                }

                settings[key] = ConfigValue(type: typeString, value: value)
            }
        }

        return PluginConfig(settings: settings)
    }
}

// MARK: - 配置监听
extension PluginConfigManager {
    /// 监听配置变化的回调类型
    typealias ConfigChangeCallback = (String, String, Any?) -> Void

    private static var configChangeCallbacks: [String: ConfigChangeCallback] = [:]

    /// 注册配置变化监听器
    /// - Parameters:
    ///   - pluginName: 插件名称
    ///   - callback: 变化回调
    func registerConfigChangeListener(
        for pluginName: String, callback: @escaping ConfigChangeCallback
    ) {
        Self.configChangeCallbacks[pluginName] = callback
    }

    /// 注销配置变化监听器
    /// - Parameter pluginName: 插件名称
    func unregisterConfigChangeListener(for pluginName: String) {
        Self.configChangeCallbacks.removeValue(forKey: pluginName)
    }

    private func notifyConfigChange(pluginName: String, key: String, value: Any?) {
        Self.configChangeCallbacks[pluginName]?(pluginName, key, value)
    }
}
