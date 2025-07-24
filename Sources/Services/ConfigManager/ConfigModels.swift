import Foundation
import Carbon

// 搜索目录数据结构
struct SearchDirectory: Identifiable, Codable, Hashable {
    var id: String { path } // 使用路径作为 ID，确保稳定性
    let path: String
    
    init(path: String) {
        self.path = path
    }
    
    // 自定义编码，只保存路径
    private enum CodingKeys: String, CodingKey {
        case path
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
    }
}

// 配置数据结构
struct AppConfig: Codable {
    var hotKey: HotKeyConfig
    var searchDirectories: [SearchDirectory]
    var commonAbbreviations: [String: [String]]
    var modes: ModesConfig
    
    struct HotKeyConfig: Codable {
        var modifiers: UInt32
        var keyCode: UInt32
        
        init(modifiers: UInt32 = UInt32(optionKey), keyCode: UInt32 = UInt32(kVK_Space)) {
            self.modifiers = modifiers
            self.keyCode = keyCode
        }
    }
    
    struct ModesConfig: Codable {
        var enabled: [String: Bool]
        var showCommandSuggestions: Bool
        var defaultSearchEngine: String
        var preferredTerminal: String
        var enabledBrowsers: [String]
        var fileBrowserStartPaths: [String]
        
        static let allModes: [String] = [
            "kill", "search", "web", "terminal", "file", "clip", "plugin", "launch"
        ]
        
        init() {
            self.enabled = Dictionary(uniqueKeysWithValues: Self.allModes.map { ($0, true) })
            self.showCommandSuggestions = true
            self.defaultSearchEngine = "google"
            self.preferredTerminal = "auto"
            self.enabledBrowsers = ["safari"]
            self.fileBrowserStartPaths = [
                NSHomeDirectory(),
                NSHomeDirectory() + "/Desktop",
                NSHomeDirectory() + "/Downloads",
                NSHomeDirectory() + "/Documents"
            ]
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let enabled = try? container.decode([String: Bool].self, forKey: .enabled) {
                self.enabled = enabled
            } else {
                var dict: [String: Bool] = [:]
                dict["kill"] = (try? container.decode(Bool.self, forKey: .killModeEnabled)) ?? true
                dict["search"] = (try? container.decode(Bool.self, forKey: .searchModeEnabled)) ?? true
                dict["web"] = (try? container.decode(Bool.self, forKey: .webModeEnabled)) ?? true
                dict["terminal"] = (try? container.decode(Bool.self, forKey: .terminalModeEnabled)) ?? true
                dict["file"] = (try? container.decode(Bool.self, forKey: .fileModeEnabled)) ?? true
                dict["clip"] = true
                dict["plugin"] = true
                dict["launch"] = true
                self.enabled = dict
            }
            self.showCommandSuggestions = (try? container.decode(Bool.self, forKey: .showCommandSuggestions)) ?? true
            self.defaultSearchEngine = (try? container.decode(String.self, forKey: .defaultSearchEngine)) ?? "google"
            self.preferredTerminal = (try? container.decode(String.self, forKey: .preferredTerminal)) ?? "auto"
            self.enabledBrowsers = (try? container.decode([String].self, forKey: .enabledBrowsers)) ?? ["safari"]
            self.fileBrowserStartPaths = (try? container.decode([String].self, forKey: .fileBrowserStartPaths)) ?? [
                NSHomeDirectory(),
                NSHomeDirectory() + "/Desktop",
                NSHomeDirectory() + "/Downloads",
                NSHomeDirectory() + "/Documents",
                "/"
            ]
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(enabled, forKey: .enabled)
            try container.encode(showCommandSuggestions, forKey: .showCommandSuggestions)
            try container.encode(defaultSearchEngine, forKey: .defaultSearchEngine)
            try container.encode(preferredTerminal, forKey: .preferredTerminal)
            try container.encode(enabledBrowsers, forKey: .enabledBrowsers)
            try container.encode(fileBrowserStartPaths, forKey: .fileBrowserStartPaths)
        }
        
        private enum CodingKeys: String, CodingKey {
            case enabled
            case killModeEnabled, searchModeEnabled, webModeEnabled, terminalModeEnabled, fileModeEnabled
            case showCommandSuggestions, defaultSearchEngine, preferredTerminal, enabledBrowsers, fileBrowserStartPaths
        }
    }
}

// 插件元数据结构
struct PluginMeta: Codable, Identifiable {
    var id: String { name }
    let name: String
    var enabled: Bool
    var command: String
    var version: String?
    var description: String?
    var path: String?
}

struct PluginsConfig: Codable {
    var plugins: [PluginMeta]
}
