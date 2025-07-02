import Foundation
import Yams

// MARK: - 插件配置管理器
@MainActor
class PluginConfigManager: @unchecked Sendable {
    static let shared = PluginConfigManager()
    
    private let configsDirectory: URL
    private let dataDirectory: URL
    
    private init() {
        let lightLauncherDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        
        self.configsDirectory = lightLauncherDir.appendingPathComponent("configs")
        self.dataDirectory = lightLauncherDir.appendingPathComponent("data")
        
        createDirectoriesIfNeeded()
    }
    
    // MARK: - 公开方法
    
    /// 获取插件配置文件路径
    func getConfigPath(for pluginName: String) -> URL {
        return configsDirectory.appendingPathComponent("\(pluginName).yaml")
    }
    
    /// 获取插件数据目录路径
    func getDataDirectory(for pluginName: String) -> URL {
        return dataDirectory.appendingPathComponent(pluginName)
    }
    
    /// 读取插件配置
    func readConfig<T: Codable>(for pluginName: String, type: T.Type) -> T? {
        let configPath = getConfigPath(for: pluginName)
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }
        
        do {
            let yamlString = try String(contentsOf: configPath, encoding: .utf8)
            let decoder = YAMLDecoder()
            return try decoder.decode(type, from: yamlString)
        } catch {
            print("Failed to read config for plugin \(pluginName): \(error)")
            return nil
        }
    }
    
    /// 写入插件配置
    func writeConfig<T: Codable>(for pluginName: String, config: T) -> Bool {
        let configPath = getConfigPath(for: pluginName)
        
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)
            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to write config for plugin \(pluginName): \(error)")
            return false
        }
    }
    
    /// 获取所有插件配置文件
    func getAllPluginConfigs() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: configsDirectory, 
                                                                   includingPropertiesForKeys: nil, 
                                                                   options: [.skipsHiddenFiles])
            return files
                .filter { $0.pathExtension == "yaml" }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            print("Failed to list plugin configs: \(error)")
            return []
        }
    }
    
    /// 删除插件配置
    func deleteConfig(for pluginName: String) -> Bool {
        let configPath = getConfigPath(for: pluginName)
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return true // 文件不存在，认为删除成功
        }
        
        do {
            try FileManager.default.removeItem(at: configPath)
            return true
        } catch {
            print("Failed to delete config for plugin \(pluginName): \(error)")
            return false
        }
    }
    
    /// 创建默认配置文件
    func createDefaultConfig(for pluginName: String, config: PluginConfig) -> Bool {
        let configPath = getConfigPath(for: pluginName)
        
        // 如果配置文件已存在，不覆盖
        guard !FileManager.default.fileExists(atPath: configPath.path) else {
            return true
        }
        
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)
            try yamlString.write(to: configPath, atomically: true, encoding: String.Encoding.utf8)
            return true
        } catch {
            print("Failed to create default config for plugin \(pluginName): \(error)")
            return false
        }
    }
    
    // MARK: - 私有方法
    
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        
        // 创建 configs 目录
        if !fileManager.fileExists(atPath: configsDirectory.path) {
            do {
                try fileManager.createDirectory(at: configsDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
                print("Created configs directory at: \(configsDirectory.path)")
            } catch {
                print("Failed to create configs directory: \(error)")
            }
        }
        
        // 创建 data 目录
        if !fileManager.fileExists(atPath: dataDirectory.path) {
            do {
                try fileManager.createDirectory(at: dataDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
                print("Created data directory at: \(dataDirectory.path)")
            } catch {
                print("Failed to create data directory: \(error)")
            }
        }
    }
}

// MARK: - 通用插件配置结构
struct PluginConfig: Codable {
    let enabled: Bool
    let settings: [String: AnyCodable]
    let version: String
    
    init(enabled: Bool = true, settings: [String: Any] = [:], version: String = "1.0.0") {
        self.enabled = enabled
        self.settings = settings.mapValues { AnyCodable($0) }
        self.version = version
    }
}

// MARK: - 支持任意类型编码的包装器
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, 
                                           DecodingError.Context(codingPath: decoder.codingPath, 
                                                               debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, 
                                           EncodingError.Context(codingPath: encoder.codingPath, 
                                                               debugDescription: "Unsupported type"))
        }
    }
}
