import Foundation
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
            try FileManager.default.createDirectory(
                at: configDirectory, withIntermediateDirectories: true, attributes: nil)
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
        self.pluginsConfig =
            Self.loadPluginsConfig(from: pluginsConfigURL) ?? PluginsConfig(plugins: [])

        // 加载模式设置到 SettingsManager
        Task { @MainActor in
            loadModeSettings()
        }
    }

    // 创建默认配置
    private static func createDefaultConfig() -> AppConfig {
        return AppConfig(
            hotKey: AppConfig.HotKeyConfig(),
            customHotKeys: AppConfigDefaults.customHotKeys,
            searchDirectories: AppConfigDefaults.searchDirectories,
            commonAbbreviations: AppConfigDefaults.commonAbbreviations,
            modes: AppConfigDefaults.modes
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
            var customHotKeys: [CustomHotKeyConfig] = AppConfigDefaults.customHotKeys
            var searchDirectories: [String]
            var commonAbbreviations: [String: [String]]
        }
        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            let oldConfig = try decoder.decode(OldAppConfig.self, from: yamlString)
            return AppConfig(
                hotKey: oldConfig.hotKey,
                customHotKeys: oldConfig.customHotKeys,
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

    // 重置为默认配置
    func resetToDefaults() {
        config = Self.createDefaultConfig()
        saveConfig()
        // 同步模式设置
        loadModeSettings()
        // 通知热键变化
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
}
