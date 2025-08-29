import Foundation
import Yams

extension ConfigManager {
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
