import Foundation
import JavaScriptCore

struct PluginManifest: Decodable {
    let name: String
    let version: String
    let displayName: String
    let description: String?
    let command: String
    let placeholder: String?
    let iconName: String?
    let shouldHideWindowAfterAction: Bool?
    let help: [String]?
    let permissions: [PluginPermissionSpec]?
    let interface: String?
}

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
    init(type: PluginPermissionType, directories: [String]? = nil) {
        self.type = type
        self.directories = directories
    }
}

class Plugin: Identifiable {
    // MARK: - 核心属性
    let id: String
    let url: URL
    let manifest: PluginManifest
    let script: String
    let effectiveConfig: [String: Any]
    
    // MARK: - 基本信息
    var name: String { manifest.name }
    var version: String { manifest.version }
    var description: String { manifest.description ?? "" }
    var command: String { manifest.command }
    var permissions: [String] { manifest.permissions?.map { $0.type.rawValue } ?? [] }
    
    // MARK: - 运行时状态
    var isEnabled: Bool = true
    var context: JSContext?
    
    // MARK: - 初始化
    init(url: URL, manifest: PluginManifest, script: String, effectiveConfig: [String: Any]) {
        self.id = manifest.name
        self.url = url
        self.manifest = manifest
        self.script = script
        self.effectiveConfig = effectiveConfig
    }
}
