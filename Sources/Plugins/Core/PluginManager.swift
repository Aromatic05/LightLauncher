import Foundation

/// 插件管理器 - 插件系统的核心管理类
@MainActor
class PluginManager {
    static let shared = PluginManager()
    
    private let loader: PluginLoader
    private let configManager: PluginConfigManager
    private var loadedPlugins: [Plugin] = []
    
    private init() {
        self.configManager = PluginConfigManager.shared
        self.loader = PluginLoader()
    }
    
    /// 初始化插件系统
    func initialize() async {
        await loadAllPlugins()
    }
    
    /// 加载所有插件
    private func loadAllPlugins() async {
        loadedPlugins = await loader.loadAllPlugins()
        print("已加载 \(loadedPlugins.count) 个插件")
    }
    
    /// 获取已加载的插件
    func getLoadedPlugins() -> [Plugin] {
        return loadedPlugins
    }
    
    /// 根据命令查找插件
    func findPlugin(by command: String) -> Plugin? {
        return loadedPlugins.first { $0.command == command }
    }
    
    /// 检查是否可以处理指定命令
    func canHandleCommand(_ command: String) -> Bool {
        return loadedPlugins.contains { $0.command == command }
    }
    
    /// 激活插件
    func activatePlugin(command: String) -> Plugin? {
        return findPlugin(by: command)
    }
    
    /// 启用插件
    func enablePlugin(_ plugin: Plugin) {
        configManager.setPluginEnabled(plugin.name, enabled: true)
    }
    
    /// 禁用插件
    func disablePlugin(_ plugin: Plugin) {
        configManager.setPluginEnabled(plugin.name, enabled: false)
    }
}
