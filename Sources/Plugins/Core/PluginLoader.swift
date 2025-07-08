
import Foundation
import Yams
import JavaScriptCore

// MARK: - 插件加载器
/// 负责从文件系统加载插件，解析manifest和脚本
@MainActor
class PluginLoader {
    private let configManager = PluginConfigManager.shared
    
    // MARK: - 加载函数
    /// 从指定路径加载插件
    func loadPlugin(at url: URL) throws -> Plugin {
        // 1. 加载并解析manifest
        let manifest = try loadManifest(from: url)
        
        // 2. 加载脚本
        let script = try loadScript(from: url)
        
        // 3. 加载配置
        let effectiveConfig = configManager.getEffectiveConfig(
            for: manifest.name,
            pluginPath: url
        )
        
        // 4. 创建并返回Plugin对象
        return Plugin(
            url: url,
            manifest: manifest,
            script: script,
            effectiveConfig: effectiveConfig
        )
    }
    
    /// 加载并解析manifest文件
    private func loadManifest(from url: URL) throws -> PluginManifest {
        let manifestPath = url.appendingPathComponent("manifest.yaml")
        
        guard FileManager.default.fileExists(atPath: manifestPath.path) else {
            throw PluginError.missingMainFile(manifestPath.path)
        }
        
        do {
            let manifestData = try Data(contentsOf: manifestPath)
            let manifest = try YAMLDecoder().decode(PluginManifest.self, from: manifestData)
            return manifest
        } catch {
            throw PluginError.invalidManifest(error.localizedDescription)
        }
    }
    
    /// 加载插件脚本
    private func loadScript(from url: URL) throws -> String {
        let scriptPath = url.appendingPathComponent("index.js")
        
        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            throw PluginError.missingScript(scriptPath.path)
        }
        
        do {
            return try String(contentsOf: scriptPath, encoding: .utf8)
        } catch {
            throw PluginError.invalidScript(scriptPath.path)
        }
    }
    
    // MARK: - 验证函数
    /// 验证插件脚本的语法
    func validateScript(_ script: String) -> Bool {
        let context = JSContext()!
        var isValid = true
        
        // 设置异常处理程序以捕获语法错误
        context.exceptionHandler = { _, exception in
            isValid = false
            if let exception = exception {
                print("JavaScript 语法错误: \(exception)")
            }
        }
        
        // 尝试评估脚本
        context.evaluateScript(script)
        
        return isValid
    }
    
    /// 验证插件清单的有效性
    func validateManifest(_ manifest: PluginManifest) -> Bool {
        // 验证必要字段
        guard !manifest.name.isEmpty,
              !manifest.version.isEmpty,
              !manifest.command.isEmpty else {
            return false
        }
        
        // 验证命令格式（必须以/开头）
        guard manifest.command.starts(with: "/") else {
            return false
        }
        
        return true
    }
    
    /// 检查两个插件是否存在命令冲突
    func hasCommandConflict(plugin: Plugin, againstPlugins plugins: [Plugin]) -> Bool {
        return plugins.contains { $0.id != plugin.id && $0.command == plugin.command }
    }
    
    // MARK: - 批量加载
    /// 加载所有可用的插件
    func loadAllPlugins() async -> [Plugin] {
        let pluginURLs = configManager.discoverPlugins()
        var loadedPlugins: [Plugin] = []
        
        for url in pluginURLs {
            do {
                let plugin = try loadPlugin(at: url)
                
                // 检查命令冲突
                if !hasCommandConflict(plugin: plugin, againstPlugins: loadedPlugins) {
                    loadedPlugins.append(plugin)
                    
                    // 确保它在注册表中
                    configManager.registerPlugin(
                        name: plugin.name,
                        command: plugin.command,
                        version: plugin.version,
                        path: url.path
                    )
                } else {
                    print("警告: 插件命令冲突，跳过加载 '\(plugin.name)'")
                }
            } catch {
                print("加载插件失败 (\(url.lastPathComponent)): \(error)")
            }
        }
        
        return loadedPlugins
    }
}
