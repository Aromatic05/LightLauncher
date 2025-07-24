import Foundation
import Carbon
import Yams

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var config: AppConfig
    @Published var pluginsConfig: PluginsConfig = PluginsConfig(plugins: [])
    
    // 配置文件路径
    let configURL: URL
    let pluginsConfigURL: URL
    
    private init() {
        // 创建配置目录
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(".config/LightLauncher")
        
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("无法创建配置目录: \(error)")
        }
        
        self.configURL = configDirectory.appendingPathComponent("config.yaml")
        self.pluginsConfigURL = configDirectory.appendingPathComponent("plugins.yaml")
        
        // 加载或创建默认配置
        if let loadedConfig = Self.loadConfig(from: configURL) {
            self.config = loadedConfig
        } else {
            self.config = Self.createDefaultConfig()
            saveConfig()
        }
        
        // 加载插件配置
        self.pluginsConfig = Self.loadPluginsConfig(from: pluginsConfigURL) ?? PluginsConfig(plugins: [])
        
        // 加载模式设置到 SettingsManager
        Task { @MainActor in
            loadModeSettings()
        }
    }
    
    // 创建默认配置
    private static func createDefaultConfig() -> AppConfig {
        return AppConfig(
            hotKey: AppConfig.HotKeyConfig(),
            searchDirectories: [
                SearchDirectory(path: "/Applications"),
                SearchDirectory(path: "/Applications/Utilities"),
                SearchDirectory(path: "/System/Applications"),
                SearchDirectory(path: "/System/Applications/Utilities"),
                SearchDirectory(path: "~/Applications")
            ],
            commonAbbreviations: [
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
            ],
            modes: AppConfig.ModesConfig()
        )
    }
    
    // 从文件加载配置
    private static func loadConfig(from url: URL) -> AppConfig? {
        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            var config = try decoder.decode(AppConfig.self, from: yamlString)
            config = migrateConfig(config)
            return config
        } catch {
            print("加载配置文件失败: \(error)")
            return tryMigrateOldConfig(from: url)
        }
    }
    
    private static func migrateConfig(_ config: AppConfig) -> AppConfig {
        return config
    }
    
    private static func tryMigrateOldConfig(from url: URL) -> AppConfig? {
        struct OldAppConfig: Codable {
            var hotKey: AppConfig.HotKeyConfig
            var searchDirectories: [String]
            var commonAbbreviations: [String: [String]]
        }
        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            let oldConfig = try decoder.decode(OldAppConfig.self, from: yamlString)
            return AppConfig(
                hotKey: oldConfig.hotKey,
                searchDirectories: oldConfig.searchDirectories.map { SearchDirectory(path: $0) },
                commonAbbreviations: oldConfig.commonAbbreviations,
                modes: AppConfig.ModesConfig()
            )
        } catch {
            print("迁移旧配置失败: \(error)")
            return nil
        }
    }
    
    func saveConfig() {
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(config)
            let commentedYaml = """
# LightLauncher 配置文件
# 修改此文件后，需要重启应用或在设置中点击\"重新加载配置\"

# 全局热键配置
# modifiers: 修饰键组合 (可选值: 256=Cmd, 512=Shift, 1024=Option, 2048=Ctrl)
# 特殊值: 1048592=右Cmd, 1048640=右Option
# keyCode: 按键代码 (0表示仅修饰键, 49=Space, 36=Return 等)

# 功能模式配置
# killModeEnabled: 启用关闭应用模式 (/k)
# searchModeEnabled: 启用网页搜索模式 (/s)
# webModeEnabled: 启用网页打开模式 (/w)
# terminalModeEnabled: 启用终端执行模式 (/t)
# showCommandSuggestions: 输入 / 时显示命令提示
# defaultSearchEngine: 默认搜索引擎 (google, baidu, bing)
# preferredTerminal: 首选终端应用 (auto, terminal, iterm2, ghostty, kitty, alacritty, wezterm)
# enabledBrowsers: 启用的浏览器数据源 (safari, chrome, edge, firefox, arc)

\(yamlString)
"""
            try commentedYaml.write(to: configURL, atomically: true, encoding: .utf8)
            print("配置已保存到: \(configURL.path)")
        } catch {
            print("保存配置文件失败: \(error)")
        }
    }
    
    func reloadConfig() {
        if let loadedConfig = Self.loadConfig(from: configURL) {
            self.config = loadedConfig
            print("配置已重新加载")
        }
    }
    
    func updateHotKey(modifiers: UInt32, keyCode: UInt32) {
        config.hotKey.modifiers = modifiers
        config.hotKey.keyCode = keyCode
        saveConfig()
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
    
    func getHotKeyDescription() -> String {
        let modifiers = config.hotKey.modifiers
        let keyCode = config.hotKey.keyCode
        var description = ""
        if modifiers == 0x100010 {
            description += "R⌘"
        } else if modifiers == 0x100040 {
            description += "R⌥"
        } else {
            if modifiers & UInt32(cmdKey) != 0 { description += "⌘" }
            if modifiers & UInt32(optionKey) != 0 { description += "⌥" }
            if modifiers & UInt32(controlKey) != 0 { description += "⌃" }
            if modifiers & UInt32(shiftKey) != 0 { description += "⇧" }
        }
        if keyCode == 0 { return description.isEmpty ? "无" : description }
        description += getKeyName(for: keyCode)
        return description
    }
    
    private func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        default: return "Key(\(keyCode))"
        }
    }
    
    // 搜索目录管理
    func addSearchDirectory(_ path: String) {
        if !config.searchDirectories.contains(where: { $0.path == path }) {
            let newDirectory = SearchDirectory(path: path)
            config.searchDirectories.append(newDirectory)
            saveConfig()
        }
    }
    func removeSearchDirectory(_ path: String) {
        config.searchDirectories.removeAll { $0.path == path }
        saveConfig()
    }
    func removeSearchDirectory(_ directory: SearchDirectory) {
        config.searchDirectories.removeAll { $0.path == directory.path }
        saveConfig()
    }
    // 缩写管理
    func addAbbreviation(key: String, values: [String]) {
        config.commonAbbreviations[key] = values
        saveConfig()
    }
    func removeAbbreviation(key: String) {
        config.commonAbbreviations.removeValue(forKey: key)
        saveConfig()
    }
    // 模式设置管理
    func updateModeSettings() {
        let settingsManager = SettingsManager.shared
        for (key, value) in settingsManager.modeEnabled {
            switch key {
            case "kill": config.modes.enabled["kill"] = value
            case "search": config.modes.enabled["search"] = value
            case "web": config.modes.enabled["web"] = value
            case "terminal": config.modes.enabled["terminal"] = value
            case "file": config.modes.enabled["file"] = value
            case "clip": config.modes.enabled["clip"] = true
            case "plugin": config.modes.enabled["plugin"] = true
            case "launch": config.modes.enabled["launch"] = true
            default: break
            }
        }
        config.modes.showCommandSuggestions = settingsManager.showCommandSuggestions
        saveConfig()
    }
    func loadModeSettings() {
        let settingsManager = SettingsManager.shared
        settingsManager.modeEnabled["kill"] = config.modes.enabled["kill"] ?? true
        settingsManager.modeEnabled["search"] = config.modes.enabled["search"] ?? true
        settingsManager.modeEnabled["web"] = config.modes.enabled["web"] ?? true
        settingsManager.modeEnabled["terminal"] = config.modes.enabled["terminal"] ?? true
        settingsManager.modeEnabled["file"] = config.modes.enabled["file"] ?? true
        settingsManager.modeEnabled["clip"] = config.modes.enabled["clip"] ?? true
        settingsManager.modeEnabled["plugin"] = config.modes.enabled["plugin"] ?? true
        settingsManager.modeEnabled["launch"] = config.modes.enabled["launch"] ?? true
        settingsManager.showCommandSuggestions = config.modes.showCommandSuggestions
    }
    // 搜索引擎设置管理
    func updateDefaultSearchEngine(_ engine: String) {
        config.modes.defaultSearchEngine = engine
        saveConfig()
    }
    func updatePreferredTerminal(_ terminal: String) {
        config.modes.preferredTerminal = terminal
        saveConfig()
    }
    // 浏览器管理
    func updateEnabledBrowsers(_ browsers: Set<BrowserType>) {
        config.modes.enabledBrowsers = browsers.map { $0.rawValue.lowercased() }
        saveConfig()
        BrowserDataManager.shared.setEnabledBrowsers(browsers)
    }
    func getEnabledBrowsers() -> Set<BrowserType> {
        let browserTypes = Set(config.modes.enabledBrowsers.compactMap { browserString in
            BrowserType.allCases.first { $0.rawValue.lowercased() == browserString.lowercased() }
        })
        return browserTypes.isEmpty ? [.safari] : browserTypes
    }
    // 重置为默认配置
    func resetToDefaults() {
        config = Self.createDefaultConfig()
        saveConfig()
        loadModeSettings()
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
    // 文件浏览器路径管理
    func getFileBrowserStartPaths() -> [String] {
        return config.modes.fileBrowserStartPaths.filter { path in
            FileManager.default.fileExists(atPath: path)
        }
    }
    func addFileBrowserStartPath(_ path: String) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return }
        if !config.modes.fileBrowserStartPaths.contains(path) {
            config.modes.fileBrowserStartPaths.append(path)
            saveConfig()
        }
    }
    func removeFileBrowserStartPath(_ path: String) {
        config.modes.fileBrowserStartPaths.removeAll { $0 == path }
        saveConfig()
    }
    func updateFileBrowserStartPaths(_ paths: [String]) {
        let validPaths = paths.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        config.modes.fileBrowserStartPaths = validPaths
        saveConfig()
    }
    // 插件管理
    static func loadPluginsConfig(from url: URL) -> PluginsConfig? {
        do {
            _ = try String(contentsOf: url, encoding: .utf8)
            _ = YAMLDecoder()
        } catch {
            print("加载插件配置文件失败: \(error)")
            return nil
        }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            let defaultConfig = PluginsConfig(plugins: [])
            do {
                let encoder = YAMLEncoder()
                let yamlString = try encoder.encode(defaultConfig)
                let commentedYaml = """
                # LightLauncher 插件管理配置
                # 管理插件启用、命令、元数据等

                \(yamlString)
                """
                try commentedYaml.write(to: url, atomically: true, encoding: .utf8)
                print("插件配置文件不存在，已创建默认配置: \(url.path)")
            } catch let err {
                print("创建默认插件配置文件失败: \(err)")
            }
            return defaultConfig
        }
        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            return try decoder.decode(PluginsConfig.self, from: yamlString)
        } catch let err {
            print("加载插件配置文件失败: \(err)")
            return nil
        }
    }
    func savePluginsConfig() {
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(pluginsConfig)
            let commentedYaml = """
# LightLauncher 插件管理配置
# 管理插件启用、命令、元数据等

\(yamlString)
"""
            try commentedYaml.write(to: pluginsConfigURL, atomically: true, encoding: .utf8)
            print("插件配置已保存到: \(pluginsConfigURL.path)")
        } catch {
            print("保存插件配置文件失败: \(error)")
        }
    }
    func enablePlugin(_ name: String) {
        if let idx = pluginsConfig.plugins.firstIndex(where: { $0.name == name }) {
            pluginsConfig.plugins[idx].enabled = true
            savePluginsConfig()
        }
    }
    func disablePlugin(_ name: String) {
        if let idx = pluginsConfig.plugins.firstIndex(where: { $0.name == name }) {
            pluginsConfig.plugins[idx].enabled = false
            savePluginsConfig()
        }
    }
    func addOrUpdatePlugin(_ meta: PluginMeta) {
        if let idx = pluginsConfig.plugins.firstIndex(where: { $0.name == meta.name }) {
            pluginsConfig.plugins[idx] = meta
        } else {
            pluginsConfig.plugins.append(meta)
        }
        savePluginsConfig()
    }
    func removePlugin(_ name: String) {
        pluginsConfig.plugins.removeAll { $0.name == name }
        savePluginsConfig()
    }
}
