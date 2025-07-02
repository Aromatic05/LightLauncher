import Foundation
import JavaScriptCore
import os

// MARK: - 插件管理器
@MainActor
class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    // MARK: - 属性
    @Published private(set) var plugins: [String: Plugin] = [:] // 键为插件命令
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrors: [String] = []
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "PluginManager")
    
    // 插件目录路径
    private let builtinPluginsPath: URL
    private let userPluginsPath: URL
    
    private init() {
        // 内置插件路径
        builtinPluginsPath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/plugins")
        
        // 用户插件路径
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        userPluginsPath = configDir.appendingPathComponent("plugins")
        
        // 确保用户插件目录存在
        createUserPluginsDirectoryIfNeeded()
    }
    
    // MARK: - 公开方法
    
    /// 发现并加载所有插件
    func discoverPlugins() {
        Task {
            await performPluginDiscovery()
        }
    }
    
    /// 激活指定命令的插件
    func activatePlugin(command: String) -> Plugin? {
        return plugins[command]
    }
    
    /// 获取所有已加载的插件
    func getAllPlugins() -> [Plugin] {
        return Array(plugins.values)
    }
    
    /// 检查命令是否被插件处理
    func canHandleCommand(_ command: String) -> Bool {
        return plugins.keys.contains(command)
    }
    
    /// 重新加载所有插件
    func reloadPlugins() {
        plugins.removeAll()
        loadErrors.removeAll()
        discoverPlugins()
    }
    
    /// 启用/禁用插件
    func togglePlugin(command: String, enabled: Bool) {
        if var plugin = plugins[command] {
            plugin.isEnabled = enabled
            plugins[command] = plugin
            logger.info("Plugin \(plugin.name) \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// 获取所有插件命令，用于命令建议
    func getAllPluginCommands() -> [LauncherCommand] {
        return plugins.values.compactMap { plugin in
            guard plugin.isEnabled else { return nil }
            
            return LauncherCommand(
                trigger: plugin.command,
                mode: .plugin,
                description: plugin.description,
                isEnabled: true
            )
        }
    }
    
    // MARK: - 私有方法
    
    private func createUserPluginsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: userPluginsPath.path) {
            do {
                try fileManager.createDirectory(at: userPluginsPath, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
                logger.info("Created user plugins directory at: \(self.userPluginsPath.path)")
            } catch {
                logger.error("Failed to create user plugins directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func performPluginDiscovery() async {
        isLoading = true
        loadErrors.removeAll()
        
        logger.info("Starting plugin discovery...")
        
        // 加载内置插件
        await loadPluginsFromDirectory(builtinPluginsPath, type: "builtin")
        
        // 加载用户插件
        await loadPluginsFromDirectory(userPluginsPath, type: "user")
        
        isLoading = false
        
        logger.info("Plugin discovery completed. Loaded \(self.plugins.count) plugins")
        
        if !self.loadErrors.isEmpty {
            logger.warning("Plugin loading completed with \(self.loadErrors.count) errors")
        }
    }
    
    private func loadPluginsFromDirectory(_ directory: URL, type: String) async {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directory.path) else {
            logger.info("Plugin directory does not exist: \(directory.path)")
            return
        }
        
        do {
            let pluginDirs = try fileManager.contentsOfDirectory(at: directory, 
                                                                includingPropertiesForKeys: [.isDirectoryKey], 
                                                                options: [.skipsHiddenFiles])
            
            for pluginDir in pluginDirs {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: pluginDir.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }
                
                do {
                    let plugin = try await loadPlugin(from: pluginDir)
                    
                    // 检查命令冲突
                    if plugins[plugin.command] != nil {
                        let error = "Duplicate command '\(plugin.command)' in plugin '\(plugin.name)'"
                        loadErrors.append(error)
                        logger.warning("\(error)")
                        continue
                    }
                    
                    plugins[plugin.command] = plugin
                    logger.info("Loaded \(type) plugin: \(plugin.name) (\(plugin.command))")
                    
                } catch let error as PluginError {
                    let errorMsg = "Failed to load plugin from \(pluginDir.lastPathComponent): \(error.localizedDescription)"
                    loadErrors.append(errorMsg)
                    logger.error("\(errorMsg)")
                } catch {
                    let errorMsg = "Unexpected error loading plugin from \(pluginDir.lastPathComponent): \(error.localizedDescription)"
                    loadErrors.append(errorMsg)
                    logger.error("\(errorMsg)")
                }
            }
        } catch {
            let errorMsg = "Failed to read \(type) plugins directory: \(error.localizedDescription)"
            loadErrors.append(errorMsg)
            logger.error("\(errorMsg)")
        }
    }
    
    private func loadPlugin(from directoryURL: URL) async throws -> Plugin {
        let fileManager = FileManager.default
        
        // 检查 manifest.json 文件
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PluginError.manifestNotFound(manifestURL.path)
        }
        
        // 读取并解析 manifest
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try parseManifest(manifestData)
        
        // 检查 main.js 文件
        let scriptURL = directoryURL.appendingPathComponent("main.js")
        guard fileManager.fileExists(atPath: scriptURL.path) else {
            throw PluginError.scriptLoadFailed("main.js not found")
        }
        
        // 创建插件实例
        let plugin = Plugin(
            name: manifest.name,
            version: manifest.version,
            description: manifest.description,
            command: manifest.command,
            pluginDirectory: directoryURL,
            manifestPath: manifestURL,
            scriptPath: scriptURL
        )
        
        return plugin
    }
    
    private func parseManifest(_ data: Data) throws -> PluginManifest {
        do {
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
            
            // 验证必要字段
            guard !manifest.name.isEmpty else {
                throw PluginError.invalidManifest("Plugin name cannot be empty")
            }
            
            guard !manifest.command.isEmpty else {
                throw PluginError.invalidManifest("Plugin command cannot be empty")
            }
            
            guard manifest.command.hasPrefix("/") else {
                throw PluginError.invalidManifest("Plugin command must start with '/'")
            }
            
            return manifest
            
        } catch let decodingError as DecodingError {
            throw PluginError.invalidManifest("JSON decoding error: \(decodingError.localizedDescription)")
        } catch {
            throw PluginError.invalidManifest(error.localizedDescription)
        }
    }
}

// MARK: - 插件清单数据结构
private struct PluginManifest: Codable {
    let name: String
    let version: String
    let description: String
    let command: String
    let author: String?
    let homepage: String?
    let main: String? // 默认为 "main.js"
    
    enum CodingKeys: String, CodingKey {
        case name, version, description, command, author, homepage, main
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        description = try container.decode(String.self, forKey: .description)
        command = try container.decode(String.self, forKey: .command)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        main = try container.decodeIfPresent(String.self, forKey: .main) ?? "main.js"
    }
}
