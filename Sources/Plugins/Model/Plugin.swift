import Foundation
import JavaScriptCore

// MARK: - 插件实体
struct Plugin: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let description: String
    let command: String // 触发命令，如 "/todo"
    
    // JavaScript 上下文和 API 管理器
    var context: JSContext?
    var apiManager: APIManager?
    var isEnabled: Bool = true
    
    // 插件文件路径信息
    let pluginDirectory: URL
    let manifestPath: URL
    let scriptPath: URL
    
    init(name: String, version: String, description: String, command: String, 
         pluginDirectory: URL, manifestPath: URL, scriptPath: URL) {
        self.name = name
        self.version = version
        self.description = description
        self.command = command
        self.pluginDirectory = pluginDirectory
        self.manifestPath = manifestPath
        self.scriptPath = scriptPath
    }
}

// MARK: - 插件状态
extension Plugin {
    var isLoaded: Bool {
        return context != nil
    }
    
    var displayName: String {
        return "\(name) v\(version)"
    }
}
