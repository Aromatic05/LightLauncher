import Foundation
import JavaScriptCore
import os
import Yams

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
            await performPluginDiscoveryFromConfig()
        }
    }
    
    /// 生成 plugins.yaml 配置，自动发现所有插件
    func buildPluginsConfig() -> PluginsConfig {
        let pluginsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/LightLauncher/plugins")
        var metas: [PluginMeta] = []
        if let pluginDirs = try? FileManager.default.contentsOfDirectory(at: pluginsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for dir in pluginDirs {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                    // 读取 manifest.yaml/json
                    let yamlManifest = dir.appendingPathComponent("manifest.yaml")
                    let jsonManifest = dir.appendingPathComponent("manifest.json")
                    var name = dir.lastPathComponent
                    var command = "/" + name
                    var version: String? = nil
                    var desc: String? = nil
                    if FileManager.default.fileExists(atPath: yamlManifest.path) {
                        if let data = try? Data(contentsOf: yamlManifest),
                           let dict = try? Yams.load(yaml: String(data: data, encoding: .utf8) ?? "") as? [String: Any] {
                            name = dict["name"] as? String ?? name
                            command = dict["command"] as? String ?? command
                            version = dict["version"] as? String
                            desc = dict["description"] as? String
                        }
                    } else if FileManager.default.fileExists(atPath: jsonManifest.path) {
                        if let data = try? Data(contentsOf: jsonManifest),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            name = dict["name"] as? String ?? name
                            command = dict["command"] as? String ?? command
                            version = dict["version"] as? String
                            desc = dict["description"] as? String
                        }
                    }
                    let meta = PluginMeta(name: name, enabled: true, command: command, version: version, description: desc, path: dir.path)
                    metas.append(meta)
                }
            }
        }
        let newConfig = PluginsConfig(plugins: metas)
        // 保存新配置
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/LightLauncher/plugins.yaml")
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(newConfig)
            let commentedYaml = """
# LightLauncher 插件管理配置
# 管理插件启用、命令、元数据等

\(yamlString)
"""
            try commentedYaml.write(to: url, atomically: true, encoding: .utf8)
            print("插件配置已重建: \(url.path)")
        } catch {
            print("保存新插件配置文件失败: \(error)")
        }
        // 同步到 ConfigManager
        ConfigManager.shared.pluginsConfig = newConfig
        return newConfig
    }

    /// 从 plugins.yaml 配置发现插件
    private func performPluginDiscoveryFromConfig() async {
        isLoading = true
        loadErrors.removeAll()
        plugins.removeAll()
        logger.info("Starting plugin discovery from plugins.yaml...")
        var pluginMetas = ConfigManager.shared.pluginsConfig.plugins
        // 检查 plugins.yaml 是否存在且可用，否则重建
        let pluginsConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/LightLauncher/plugins.yaml")
        if pluginMetas.isEmpty, !FileManager.default.fileExists(atPath: pluginsConfigURL.path) {
            logger.info("plugins.yaml 不存在，自动生成...")
            let newConfig = buildPluginsConfig()
            pluginMetas = newConfig.plugins
        } else if pluginMetas.isEmpty {
            // 文件存在但内容为空，尝试解析
            do {
                let yamlString = try String(contentsOf: pluginsConfigURL, encoding: .utf8)
                let decoder = YAMLDecoder()
                let loaded = try decoder.decode(PluginsConfig.self, from: yamlString)
                pluginMetas = loaded.plugins
            } catch {
                logger.warning("plugins.yaml 解析失败，自动重建: \(error)")
                let newConfig = buildPluginsConfig()
                pluginMetas = newConfig.plugins
            }
        }
        for meta in pluginMetas {
            guard meta.enabled, let path = meta.path else { continue }
            let dirURL = URL(fileURLWithPath: path)
            do {
                let plugin = try await loadPlugin(from: dirURL)
                // 检查命令冲突
                if plugins[plugin.command] != nil {
                    let error = "Duplicate command '\(plugin.command)' in plugin '\(plugin.name)'"
                    loadErrors.append(error)
                    logger.warning("\(error)")
                    continue
                }
                plugins[plugin.command] = plugin
                logger.info("Loaded plugin from config: \(plugin.name) (\(plugin.command))")
            } catch let error as PluginError {
                let errorMsg = "Failed to load plugin from \(dirURL.lastPathComponent): \(error.localizedDescription)"
                loadErrors.append(errorMsg)
                logger.error("\(errorMsg)")
            } catch {
                let errorMsg = "Unexpected error loading plugin from \(dirURL.lastPathComponent): \(error.localizedDescription)"
                loadErrors.append(errorMsg)
                logger.error("\(errorMsg)")
            }
        }
        isLoading = false
        logger.info("Plugin discovery from config completed. Loaded \(self.plugins.count) plugins")
        if !self.loadErrors.isEmpty {
            logger.warning("Plugin loading completed with \(self.loadErrors.count) errors")
        }
    }
    
    /// 激活指定命令的插件
    func activatePlugin(command: String) -> Plugin? {
        guard let plugin = plugins[command] else {
            return nil
        }
        // 只在 context/apiManager 为 nil 时初始化，保证单例
        if plugin.context == nil || plugin.apiManager == nil {
            logger.info("Reinitializing plugin: \(plugin.name, privacy: .public)")
            let context = JSContext()!
            context.exceptionHandler = { context, exception in
                let msg = exception?.toString() ?? "unknown error"
                self.logger.error("JavaScript error in plugin \(plugin.name): \(msg, privacy: .public)")
            }
            let apiManager = APIManager(viewModel: nil, context: context, pluginName: plugin.name, pluginCommand: plugin.command)
            context.setObject(apiManager, forKeyedSubscript: "lightlauncher" as NSString)
            logger.info("Exposing lightlauncher object to JavaScript context for plugin: \(plugin.name, privacy: .public)")
            do {
                let mainJSContent = try String(contentsOf: plugin.scriptPath)
                logger.info("Script content length: \(mainJSContent.count, privacy: .public) characters")
                logger.info("Evaluating JavaScript for plugin: \(plugin.name, privacy: .public)")
                context.evaluateScript(mainJSContent)
                if let exception = context.exception {
                    logger.error("JavaScript execution exception: \(exception.toString(), privacy: .public)")
                } else {
                    logger.info("JavaScript executed successfully for plugin: \(plugin.name, privacy: .public)")
                }
                plugin.context = context
                plugin.apiManager = apiManager
                // 不需要重新赋值，plugin 已为 class 实例
                logger.info("Successfully reinitialized plugin: \(plugin.name, privacy: .public)")
            } catch {
                logger.error("Failed to reinitialize plugin \(plugin.name): \(error, privacy: .public)")
                return nil
            }
        }
        return plugin
    }
    
    /// 获取所有已加载的插件
    func getAllPlugins() -> [Plugin] {
        return Array(plugins.values)
    }
    
    /// 检查命令是否被插件处理
    func canHandleCommand(_ command: String) -> Bool {
        return plugins.keys.contains(command)
    }
    
    /// 启用/禁用插件
    func togglePlugin(command: String, enabled: Bool) {
        if var plugin = plugins[command] {
            plugin.isEnabled = enabled
            plugins[command] = plugin
            // 同步到 plugins.yaml
            if let meta = ConfigManager.shared.pluginsConfig.plugins.first(where: { $0.command == command }) {
                if enabled {
                    ConfigManager.shared.enablePlugin(meta.name)
                } else {
                    ConfigManager.shared.disablePlugin(meta.name)
                }
            }
            logger.info("Plugin \(plugin.name) \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// 重新加载所有插件
    func reloadPlugins() {
        plugins.removeAll()
        loadErrors.removeAll()
        discoverPlugins()
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
        // 优先检查 manifest.yaml 文件，如果不存在则使用 manifest.json
        let yamlManifestURL = directoryURL.appendingPathComponent("manifest.yaml")
        let jsonManifestURL = directoryURL.appendingPathComponent("manifest.json")
        let manifestURL: URL
        var useYAML = false
        if fileManager.fileExists(atPath: yamlManifestURL.path) {
            manifestURL = yamlManifestURL
            useYAML = true
        } else if fileManager.fileExists(atPath: jsonManifestURL.path) {
            manifestURL = jsonManifestURL
            useYAML = false
        } else {
            throw PluginError.manifestNotFound("Neither manifest.yaml nor manifest.json found")
        }
        // 读取并解析 manifest
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try parseManifest(manifestData, isYAML: useYAML)
        // 检查 main.js 文件
        let scriptURL = directoryURL.appendingPathComponent("main.js")
        guard fileManager.fileExists(atPath: scriptURL.path) else {
            throw PluginError.scriptLoadFailed("main.js not found")
        }
        // 创建插件实例（class）
        let plugin = Plugin(
            name: manifest.name,
            version: manifest.version,
            description: manifest.description,
            command: manifest.command,
            pluginDirectory: directoryURL,
            manifestPath: manifestURL,
            scriptPath: scriptURL,
            shouldHideWindowAfterAction: manifest.shouldHideWindowAfterAction ?? true
        )
        logger.info("Loaded plugin \(manifest.name) with shouldHideWindowAfterAction: \(plugin.shouldHideWindowAfterAction)")
        // 创建并配置 JavaScript 上下文
        try await setupJavaScriptContext(for: plugin, scriptURL: scriptURL)
        return plugin
    }
    
    private func parseManifest(_ data: Data, isYAML: Bool = false) throws -> PluginManifest {
        do {
            let manifest: PluginManifest
            
            if isYAML {
                // 解析 YAML 格式
                let yamlString = String(data: data, encoding: .utf8) ?? ""
                manifest = try YAMLDecoder().decode(PluginManifest.self, from: yamlString)
            } else {
                // 解析 JSON 格式
                manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
            }
            
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
            let format = isYAML ? "YAML" : "JSON"
            throw PluginError.invalidManifest("\(format) decoding error: \(decodingError.localizedDescription)")
        } catch {
            throw PluginError.invalidManifest(error.localizedDescription)
        }
    }
    
    // MARK: - JavaScript 上下文设置
    
    /// 为插件设置 JavaScript 上下文
    private func setupJavaScriptContext(for plugin: Plugin, scriptURL: URL) async throws {
        // 创建 JavaScript 上下文
        let context = JSContext()
        
        guard let context = context else {
            throw PluginError.scriptLoadFailed("Failed to create JavaScript context")
        }
        
        // 创建 API 管理器实例 (先用 nil，稍后会注入 viewModel)
        let apiManager = APIManager(viewModel: nil, context: context, pluginName: plugin.name, pluginCommand: plugin.command)
        
        // 将 API 管理器暴露给 JavaScript
        context.setObject(apiManager, forKeyedSubscript: "lightlauncher" as NSString)
        
        // 验证对象是否正确暴露（添加调试输出）
        let testResult = context.evaluateScript("typeof lightlauncher")
        logger.info("Initial setup - lightlauncher object type in JS context: \(testResult?.toString() ?? "undefined", privacy: .public)")
        
        let writeFileTest = context.evaluateScript("typeof lightlauncher.writeFile")
        logger.info("Initial setup - lightlauncher.writeFile type in JS context: \(writeFileTest?.toString() ?? "undefined", privacy: .public)")
        
        let logTest = context.evaluateScript("typeof lightlauncher.log")
        logger.info("Initial setup - lightlauncher.log type in JS context: \(logTest?.toString() ?? "undefined", privacy: .public)")
        
        let pluginName = plugin.name
        
        context.exceptionHandler = { [weak self] context, exception in
            let errorMessage = exception?.toString() ?? "Unknown JavaScript error"
            self?.logger.error("JavaScript execution error in plugin \(pluginName): \(errorMessage)")
            
            // 清除异常以防止传播
            context?.exception = nil
        }
        
        do {
            let scriptContent = try String(contentsOf: scriptURL, encoding: .utf8)
            let result = context.evaluateScript(scriptContent)
            
            if let exception = context.exception {
                throw PluginError.scriptLoadFailed("Script execution failed: \(exception)")
            }
            
            if result?.isUndefined == false {
                logger.debug("Successfully executed script for plugin: \(pluginName)")
            }
            
        } catch {
            throw PluginError.scriptLoadFailed("Failed to load script file: \(error.localizedDescription)")
        }
        
        // 直接赋值到 class 实例属性
        plugin.context = context
        plugin.apiManager = apiManager
        
        logger.info("JavaScript context setup completed for plugin: \(pluginName)")
    }
    
    /// 重置插件的 JSContext 和 APIManager，仅供 PluginExecutor 调用
    func resetPlugin(for command: String) async {
        guard let plugin = plugins[command] else { return }
        plugin.apiManager?.cleanup()
        plugin.apiManager = nil
        plugin.context = nil
        logger.debug("Reset plugin: \(plugin.name)")
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
    let shouldHideWindowAfterAction: Bool? // 默认为 true
    
    // 可选的扩展字段（简化版本）
    let metadata: PluginMetadata?
    
    enum CodingKeys: String, CodingKey {
        case name, version, description, command, author, homepage, main
        case shouldHideWindowAfterAction = "should_hide_window_after_action"
        case metadata
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
        shouldHideWindowAfterAction = try container.decodeIfPresent(Bool.self, forKey: .shouldHideWindowAfterAction) ?? true
        
        // 扩展字段（可选）
        metadata = try container.decodeIfPresent(PluginMetadata.self, forKey: .metadata)
    }
}

// MARK: - 插件元数据结构
private struct PluginMetadata: Codable {
    let category: String?
    let tags: [String]?
}
