import Foundation

// 配置数据结构
struct AppConfig: Codable {
    var hotKey: HotKeyConfig
    var customHotKeys: [CustomHotKeyConfig]  // 新增自定义快捷键数组
    var searchDirectories: [SearchDirectory]
    var commonAbbreviations: [String: [String]]
    // 日志配置
    var logging: LoggingConfig
    var modes: ModesConfig

    struct LoggingConfig: Codable {
        enum LogLevel: String, Codable {
            case debug
            case info
            case warning
            case error
        }

        var printToTerminal: Bool
        var logToFile: Bool
        var consoleLevel: LogLevel
        var fileLevel: LogLevel
        var customFilePath: String?

        init(printToTerminal: Bool = true,
             logToFile: Bool = false,
             consoleLevel: LogLevel = .info,
             fileLevel: LogLevel = .debug,
             customFilePath: String? = nil) {
            self.printToTerminal = printToTerminal
            self.logToFile = logToFile
            self.consoleLevel = consoleLevel
            self.fileLevel = fileLevel
            self.customFilePath = customFilePath
        }
    }

    struct HotKeyConfig: Codable {
        var hotkey: HotKey

        init(hotkey: HotKey = HotKey(keyCode: UInt32(kVK_Space), option: true)) {
            self.hotkey = hotkey
        }
    }

    struct ModesConfig: Codable {
        var enabled: [String: Bool]
        var showCommandSuggestions: Bool
        var defaultSearchEngine: String
        var preferredTerminal: String
        var enabledBrowsers: [String]
        var fileBrowserStartPaths: [String]
        /// 新增：KeywordMode 的自定义搜索配置
        var keywordModeConfig: KeywordModeConfig?

        static let allModes: [String] = [
            "kill", "search", "web", "terminal", "file", "clip", "plugin", "launch", "keyword",
        ]

        init(
            enabled: [String: Bool] = AppConfigDefaults.modeEnabled,
            showCommandSuggestions: Bool = AppConfigDefaults.showCommandSuggestions,
            defaultSearchEngine: String = AppConfigDefaults.defaultSearchEngine,
            preferredTerminal: String = AppConfigDefaults.preferredTerminal,
            enabledBrowsers: [String] = AppConfigDefaults.enabledBrowsers,
            fileBrowserStartPaths: [String] = AppConfigDefaults.fileBrowserStartPaths,
            keywordModeConfig: KeywordModeConfig? = nil
        ) {
            self.enabled = enabled
            self.showCommandSuggestions = showCommandSuggestions
            self.defaultSearchEngine = defaultSearchEngine
            self.preferredTerminal = preferredTerminal
            self.enabledBrowsers = enabledBrowsers
            self.fileBrowserStartPaths = fileBrowserStartPaths
            self.keywordModeConfig = keywordModeConfig
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let enabled = try? container.decode([String: Bool].self, forKey: .enabled) {
                self.enabled = enabled
            } else {
                self.enabled = AppConfigDefaults.modeEnabled
            }
            self.showCommandSuggestions =
                (try? container.decode(Bool.self, forKey: .showCommandSuggestions))
                ?? AppConfigDefaults.showCommandSuggestions
            self.defaultSearchEngine =
                (try? container.decode(String.self, forKey: .defaultSearchEngine))
                ?? AppConfigDefaults.defaultSearchEngine
            self.preferredTerminal =
                (try? container.decode(String.self, forKey: .preferredTerminal))
                ?? AppConfigDefaults.preferredTerminal
            self.enabledBrowsers =
                (try? container.decode([String].self, forKey: .enabledBrowsers))
                ?? AppConfigDefaults.enabledBrowsers
            self.fileBrowserStartPaths =
                (try? container.decode([String].self, forKey: .fileBrowserStartPaths))
                ?? AppConfigDefaults.fileBrowserStartPaths
            self.keywordModeConfig = try? container.decode(
                KeywordModeConfig.self, forKey: .keywordModeConfig)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(enabled, forKey: .enabled)
            try container.encode(showCommandSuggestions, forKey: .showCommandSuggestions)
            try container.encode(defaultSearchEngine, forKey: .defaultSearchEngine)
            try container.encode(preferredTerminal, forKey: .preferredTerminal)
            try container.encode(enabledBrowsers, forKey: .enabledBrowsers)
            try container.encode(fileBrowserStartPaths, forKey: .fileBrowserStartPaths)
            try container.encodeIfPresent(keywordModeConfig, forKey: .keywordModeConfig)
        }

        private enum CodingKeys: String, CodingKey {
            case enabled
            case killModeEnabled, searchModeEnabled, webModeEnabled, terminalModeEnabled,
                fileModeEnabled
            case showCommandSuggestions, defaultSearchEngine, preferredTerminal, enabledBrowsers,
                fileBrowserStartPaths
            case keywordModeConfig
        }
    }
}

// 搜索目录数据结构
struct SearchDirectory: Identifiable, Codable, Hashable {
    var id: String { path }  // 使用路径作为 ID，确保稳定性
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

struct KeywordSearchItem: Codable, Identifiable, Hashable {
    var id: String { keyword }
    let title: String
    let url: String  // 例如: https://www.google.com/search?q={query}
    let keyword: String  // 例如: g
    let icon: String?  // 可选，本地路径或网络地址
    let spaceEncoding: String?  // 可选，"+" 或 "%20"，默认可设为 "+"
}
struct KeywordModeConfig: Codable {
    var items: [KeywordSearchItem]
}

struct CustomHotKeyConfig: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let hotkey: HotKey
    let type: String
    let text: String

    init(name: String, hotkey: HotKey, type: String = "query", text: String) {
        self.id = name
        self.name = name
        self.hotkey = hotkey
        self.type = type
        self.text = text
    }
}
