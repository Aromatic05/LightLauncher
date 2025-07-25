import Carbon
import Foundation

// 默认配置常量
enum AppConfigDefaults {
    static let searchDirectories: [SearchDirectory] = [
        SearchDirectory(path: "/Applications"),
        SearchDirectory(path: "/Applications/Utilities"),
        SearchDirectory(path: "/System/Applications"),
        SearchDirectory(path: "/System/Applications/Utilities"),
        SearchDirectory(path: "~/Applications"),
    ]
    static let commonAbbreviations: [String: [String]] = [
        "ps": ["photoshop"],
        "ai": ["illustrator"],
        "pr": ["premiere"],
        "ae": ["after effects"],
        "id": ["indesign"],
        "lr": ["lightroom"],
        "dw": ["dreamweaver"],
        "xd": ["adobe xd"],
        "vs": ["visual studio", "code"],
        "vsc": ["visual studio code", "code"],
        "code": ["visual studio code", "code"],
        "chrome": ["google chrome"],
        "ff": ["firefox"],
        "safari": ["safari"],
        "edge": ["microsoft edge"],
        "word": ["microsoft word"],
        "excel": ["microsoft excel"],
        "ppt": ["powerpoint"],
        "outlook": ["microsoft outlook"],
        "teams": ["microsoft teams"],
        "qq": ["qq"],
        "wx": ["wechat", "微信"],
        "wechat": ["微信"],
        "git": ["github desktop", "sourcetree"],
        "vm": ["vmware", "parallels"],
    ]

    static let modeEnabled: [String: Bool] = Dictionary(
        uniqueKeysWithValues: AppConfig.ModesConfig.allModes.map { ($0, true) })
    static let showCommandSuggestions: Bool = true
    static let defaultSearchEngine: String = "google"
    static let preferredTerminal: String = "auto"
    static let enabledBrowsers: [String] = ["safari"]
    static let fileBrowserStartPaths: [String] = [
        NSHomeDirectory(),
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Documents",
    ]

    static let defaultKeywordModeConfig: KeywordModeConfig = KeywordModeConfig(
        items: defaultKeywordSearchItems)
    /// KeywordMode 默认搜索项
    static let defaultKeywordSearchItems: [KeywordSearchItem] = [
        KeywordSearchItem(
            title: "Google",
            url: "https://www.google.com/search?q={query}",
            keyword: "g",
            icon: "google.png",
            spaceEncoding: "+"
        ),
        KeywordSearchItem(
            title: "Bing",
            url: "https://www.bing.com/search?q={query}",
            keyword: "b",
            icon: "bing.png",
            spaceEncoding: "%20"
        ),
        KeywordSearchItem(
            title: "知乎",
            url: "https://www.zhihu.com/search?type=content&q={query}",
            keyword: "zh",
            icon: "zhihu.png",
            spaceEncoding: "%20"
        ),
    ]

    static let modes: AppConfig.ModesConfig = AppConfig.ModesConfig(
        enabled: modeEnabled,
        showCommandSuggestions: showCommandSuggestions,
        defaultSearchEngine: defaultSearchEngine,
        preferredTerminal: preferredTerminal,
        enabledBrowsers: enabledBrowsers,
        fileBrowserStartPaths: fileBrowserStartPaths,
        keywordModeConfig: defaultKeywordModeConfig
    )

    static let hotKey: AppConfig.HotKeyConfig = AppConfig.HotKeyConfig()

    static let defaultConfig: AppConfig = AppConfig(
        hotKey: hotKey,
        searchDirectories: searchDirectories,
        commonAbbreviations: commonAbbreviations,
        modes: modes
    )
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
