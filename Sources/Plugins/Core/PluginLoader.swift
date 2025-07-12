import Foundation
import Yams

/// 插件加载器 - 负责单个插件的加载与初始化
class PluginLoader {
    @MainActor static let shared = PluginLoader()
    
    private init() {}
    
    /// 从指定目录加载插件
    /// - Parameter directory: 插件目录路径
    /// - Returns: 加载成功的插件对象
    /// - Throws: PluginError 相关错误
    func load(from directory: URL) throws -> Plugin {
        // 1. 验证目录存在
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw PluginError.loadFailed("插件目录不存在: \(directory.path)")
        }
        
        // 2. 读取并解析 manifest.yaml
        let manifest = try loadManifest(from: directory)
        
        // 3. 读取主脚本文件
        let script = try loadScript(from: directory, manifest: manifest)
        
        // 4. 读取配置文件
        let config = try loadConfig(from: directory, manifest: manifest)
        
        // 5. 创建插件对象
        let plugin = Plugin(
            url: directory,
            manifest: manifest,
            script: script,
            effectiveConfig: config
        )
        
        // 6. 验证插件有效性
        try validatePlugin(plugin)
        
        return plugin
    }
    
    /// 加载插件清单文件
    private func loadManifest(from directory: URL) throws -> PluginManifest {
        let manifestURL = directory.appendingPathComponent("manifest.yaml")
        
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginError.invalidManifest("找不到 manifest.yaml 文件")
        }
        
        do {
            let manifestData = try Data(contentsOf: manifestURL)
            let manifestString = String(data: manifestData, encoding: .utf8) ?? ""
            
            let decoder = YAMLDecoder()
            let manifest = try decoder.decode(PluginManifest.self, from: manifestString)
            
            // 基本验证
            if manifest.name.isEmpty {
                throw PluginError.invalidManifest("插件名称不能为空")
            }
            if manifest.version.isEmpty {
                throw PluginError.invalidManifest("插件版本不能为空")
            }
            if manifest.command.isEmpty {
                throw PluginError.invalidManifest("插件命令不能为空")
            }
            
            return manifest
        } catch let error as DecodingError {
            throw PluginError.invalidManifest("清单文件解析失败: \(error.localizedDescription)")
        } catch {
            throw PluginError.invalidManifest("读取清单文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 加载插件脚本文件
    private func loadScript(from directory: URL, manifest: PluginManifest) throws -> String {
        let mainFile = manifest.main ?? "main.js"
        let scriptURL = directory.appendingPathComponent(mainFile)
        
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw PluginError.missingMainFile("找不到主脚本文件: \(mainFile)")
        }
        
        do {
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
            if script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw PluginError.invalidScript("主脚本文件为空")
            }
            return script
        } catch {
            throw PluginError.invalidScript("读取主脚本文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 加载插件配置文件
    private func loadConfig(from directory: URL, manifest: PluginManifest) throws -> [String: Any] {
        let configURL = directory.appendingPathComponent("config.yaml")
        
        // 配置文件是可选的
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return [:]
        }
        
        do {
            let configData = try Data(contentsOf: configURL)
            let configString = String(data: configData, encoding: .utf8) ?? ""
            
            let yaml = try Yams.load(yaml: configString)
            
            // 将 YAML 转换为 Swift 字典
            if let configDict = yaml as? [String: Any] {
                return configDict
            } else {
                return [:]
            }
        } catch {
            // 配置文件解析失败不应该阻止插件加载
            print("警告: 插件 \(manifest.name) 的配置文件解析失败: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// 验证插件的有效性
    private func validatePlugin(_ plugin: Plugin) throws {
        // 验证插件名称格式
        if !isValidPluginName(plugin.name) {
            throw PluginError.invalidManifest("插件名称格式无效: \(plugin.name)")
        }
        
        // 验证版本格式
        if !isValidVersion(plugin.version) {
            throw PluginError.invalidManifest("版本格式无效: \(plugin.version)")
        }
        
        // 验证命令格式
        if !isValidCommand(plugin.command) {
            throw PluginError.invalidManifest("命令格式无效: \(plugin.command)")
        }
        
        // 验证权限格式
        if let permissions = plugin.manifest.permissions {
            for permission in permissions {
                if !isValidPermission(permission) {
                    throw PluginError.invalidManifest("权限格式无效: \(permission.type.rawValue)")
                }
            }
        }
    }
    
    // MARK: - 验证辅助方法
    
    private func isValidPluginName(_ name: String) -> Bool {
        // 插件名称只能包含字母、数字、下划线和连字符
        let regex = try? NSRegularExpression(pattern: "^[a-zA-Z0-9_-]+$")
        let range = NSRange(location: 0, length: name.utf16.count)
        return regex?.firstMatch(in: name, range: range) != nil
    }
    
    private func isValidVersion(_ version: String) -> Bool {
        // 简单的版本格式验证 (x.y.z)
        let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\d+\\.\\d+")
        let range = NSRange(location: 0, length: version.utf16.count)
        return regex?.firstMatch(in: version, range: range) != nil
    }
    
    private func isValidCommand(_ command: String) -> Bool {
        // 命令必须以 / 开头
        return command.hasPrefix("/") && command.count > 1
    }
    
    private func isValidPermission(_ permission: PluginPermissionSpec) -> Bool {
        // 所有定义的权限类型都是有效的
        return PluginPermissionType.allCases.contains(permission.type)
    }
    
    /// 扫描目录中的所有插件
    /// - Parameter directory: 要扫描的目录
    /// - Returns: 所有有效插件目录的 URL 数组
    func scanPluginDirectories(in directory: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            return contents.filter { url in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                // 检查是否是目录且包含 manifest.yaml
                return isDirectory.boolValue &&
                       FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.yaml").path)
            }
        } catch {
            print("扫描插件目录失败: \(error.localizedDescription)")
            return []
        }
    }
}