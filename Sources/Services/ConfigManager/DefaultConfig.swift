import Carbon
import Foundation

// 默认配置常量
enum AppConfigDefaults {
    // 默认自定义快捷键配置
    static let customHotKeys: [CustomHotKeyConfig] = [
        CustomHotKeyConfig(
            name: "剪切板", modifiers: UInt32(optionKey), keyCode: UInt32(kVK_ANSI_V), text: "/v "),
        CustomHotKeyConfig(
            name: "Code", modifiers: UInt32(optionKey), keyCode: UInt32(kVK_ANSI_C), type: "open",
            text: "/Applications/Visual Studio Code.app"),
    ]
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
    static let defaultSearchEngine: String = "Google"
    static let preferredTerminal: String = "auto"
    static let enabledBrowsers: [String] = ["safari"]
    static let fileBrowserStartPaths: [String] = [
        "/",
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
        KeywordSearchItem(
            title: "Google 翻译",
            url: "https://translate.google.com/?sl=auto&tl=zh-CN&text={query}&op=translate",
            keyword: "gt",
            icon: "googletranslate.png",
            spaceEncoding: "%20"
        ),
        KeywordSearchItem(
            title: "GitHub",
            url: "https://github.com/search?q={query}",
            keyword: "gh",
            icon: "github.png",
            spaceEncoding: "%20"
        ),
        KeywordSearchItem(
            title: "维基百科",
            url: "https://zh.wikipedia.org/wiki/{query}",
            keyword: "wiki",
            icon: "wiki.png",
            spaceEncoding: "%20"
        ),
        KeywordSearchItem(
            title: "YouTube",
            url: "https://www.youtube.com/results?search_query={query}",
            keyword: "yt",
            icon: "youtube.png",
            spaceEncoding: "+"
        ),
        KeywordSearchItem(
            title: "百度",
            url: "https://www.baidu.com/s?wd={query}",
            keyword: "bd",
            icon: "baidu.png",
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
        customHotKeys: customHotKeys,
        searchDirectories: searchDirectories,
        commonAbbreviations: commonAbbreviations,
        modes: modes
    )
}
