import Foundation
import JavaScriptCore

struct PluginManifest: Decodable {
    // 基本信息（必需）
    let name: String
    let version: String
    let displayName: String
    let description: String?
    let command: String
    let author: String?
    let main: String?  // 主入口文件，默认为 main.js

    // UI 相关（可选）
    let placeholder: String?
    let iconName: String?
    let shouldHideWindowAfterAction: Bool?

    // 帮助和文档（可选）
    let help: [String]?
    let interface: String?

    // 权限声明（可选）
    let permissions: [PluginPermissionSpec]?

    // 高级配置（可选）
    let minLightLauncherVersion: String?
    let maxLightLauncherVersion: String?
    let dependencies: [String]?
    let keywords: [String]?
    let homepage: String?
    let repository: String?

    enum CodingKeys: String, CodingKey {
        case name, version, displayName, description, command, author, main
        case placeholder, iconName, shouldHideWindowAfterAction
        case help, interface, permissions
        case minLightLauncherVersion = "min_lightlauncher_version"
        case maxLightLauncherVersion = "max_lightlauncher_version"
        case dependencies, keywords, homepage, repository
    }
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
