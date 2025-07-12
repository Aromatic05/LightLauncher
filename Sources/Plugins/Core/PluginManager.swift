import Foundation

/// 插件管理器 - 负责插件的注册、管理和生命周期控制
@MainActor
class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published private(set) var plugins: [String: Plugin] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadingProgress: Double = 0.0
    
    private let loader = PluginLoader.shared
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// 加载所有插件
    func loadAllPlugins() async {
        isLoading = true
        loadingProgress = 0.0
        
        defer {
            isLoading = false
            loadingProgress = 1.0
        }
        
        // 获取内置插件目录和用户插件目录
        let pluginDirectories = getPluginDirectories()
        
        var allPluginDirs: [URL] = []
        
        // 扫描所有插件目录
        for directory in pluginDirectories {
            let dirs = loader.scanPluginDirectories(in: directory)
            allPluginDirs.append(contentsOf: dirs)
        }
        
        guard !allPluginDirs.isEmpty else {
            print("未找到任何插件")
            return
        }
        
        let totalCount = allPluginDirs.count
        var loadedCount = 0
        
        for pluginDirectory in allPluginDirs {
            do {
                let plugin = try loader.load(from: pluginDirectory)
                
                // 检查是否已存在同名插件
                if let existingPlugin = plugins[plugin.name] {
                    print("警告: 插件 '\(plugin.name)' 已存在，将被替换")
                    print("  现有版本: \(existingPlugin.version)")
                    print("  新版本: \(plugin.version)")
                }
                
                plugins[plugin.name] = plugin
                loadedCount += 1
                loadingProgress = Double(loadedCount) / Double(totalCount)
                
                print("成功加载插件: \(plugin.name) v\(plugin.version)")
                
            } catch {
                print("加载插件失败 (\(pluginDirectory.lastPathComponent)): \(error.localizedDescription)")
                
                loadedCount += 1
                loadingProgress = Double(loadedCount) / Double(totalCount)
            }
        }
        
        print("插件加载完成: 成功加载 \(plugins.count) 个插件")
    }
    
    /// 重新加载所有插件
    func reloadPlugins() async {
        plugins.removeAll()
        await loadAllPlugins()
    }
    
    /// 注册单个插件
    /// - Parameter plugin: 要注册的插件
    func register(_ plugin: Plugin) {
        if let existingPlugin = plugins[plugin.name] {
            print("警告: 插件 '\(plugin.name)' 已存在，将被替换")
            print("  现有版本: \(existingPlugin.version)")
            print("  新版本: \(plugin.version)")
        }
        
        plugins[plugin.name] = plugin
        print("插件已注册: \(plugin.name) v\(plugin.version)")
    }
    
    /// 注销插件
    /// - Parameter name: 插件名称
    func unregister(_ name: String) {
        if let plugin = plugins.removeValue(forKey: name) {
            print("插件已注销: \(plugin.name)")
        }
    }
    
    /// 根据名称获取插件
    /// - Parameter name: 插件名称
    /// - Returns: 插件对象，如果不存在则返回 nil
    func getPlugin(named name: String) -> Plugin? {
        return plugins[name]
    }
    
    /// 根据命令获取插件
    /// - Parameter command: 插件命令
    /// - Returns: 插件对象，如果不存在则返回 nil
    func getPlugin(for command: String) -> Plugin? {
        return plugins.values.first { $0.command == command }
    }
    
    /// 获取所有已加载的插件
    /// - Returns: 插件数组
    func getLoadedPlugins() -> [Plugin] {
        return Array(plugins.values).sorted { $0.name < $1.name }
    }
    
    /// 获取启用的插件
    /// - Returns: 启用的插件数组
    func getEnabledPlugins() -> [Plugin] {
        return plugins.values.filter { $0.isEnabled }.sorted { $0.name < $1.name }
    }
    
    /// 启用插件
    /// - Parameter name: 插件名称
    func enablePlugin(_ name: String) {
        if let plugin = plugins[name] {
            plugin.isEnabled = true
            plugins[name] = plugin
            print("插件已启用: \(name)")
        }
    }
    
    /// 禁用插件
    /// - Parameter name: 插件名称
    func disablePlugin(_ name: String) {
        if let plugin = plugins[name] {
            plugin.isEnabled = false
            plugins[name] = plugin
            print("插件已禁用: \(name)")
        }
    }
    
    /// 检查插件是否存在
    /// - Parameter name: 插件名称
    /// - Returns: 是否存在
    func hasPlugin(named name: String) -> Bool {
        return plugins[name] != nil
    }
    
    /// 检查命令是否被插件占用
    /// - Parameter command: 命令字符串
    /// - Returns: 是否被占用
    func isCommandTaken(_ command: String) -> Bool {
        return plugins.values.contains { $0.command == command }
    }
    
    /// 获取插件统计信息
    /// - Returns: 统计信息字典
    func getStatistics() -> [String: Any] {
        let totalCount = plugins.count
        let enabledCount = plugins.values.filter { $0.isEnabled }.count
        let disabledCount = totalCount - enabledCount
        
        return [
            "total": totalCount,
            "enabled": enabledCount,
            "disabled": disabledCount,
            "commands": plugins.values.map { $0.command }
        ]
    }
    
    /// 获取插件目录列表
    private func getPluginDirectories() -> [URL] {
        var directories: [URL] = []
        
        // 1. 测试插件目录 (开发环境)
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let testPluginsDir = currentDir.appendingPathComponent("TestPlugins")
        if FileManager.default.fileExists(atPath: testPluginsDir.path) {
            directories.append(testPluginsDir)
        }
        
        // 2. 用户插件目录
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let userPluginsDir = homeDir.appendingPathComponent(".config/LightLauncher/plugins")
        directories.append(userPluginsDir)
        
        // 3. 应用程序支持目录
        if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                       in: .userDomainMask).first {
            let pluginsDir = appSupportDir.appendingPathComponent("LightLauncher/plugins")
            directories.append(pluginsDir)
        }
        
        return directories
    }
    
    /// 清理所有插件
    func cleanup() {
        plugins.removeAll()
        print("所有插件已清理")
    }
    
    /// 搜索插件
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的插件数组
    func searchPlugins(_ query: String) -> [Plugin] {
        guard !query.isEmpty else {
            return getLoadedPlugins()
        }
        
        let lowercaseQuery = query.lowercased()
        
        return plugins.values.filter { plugin in
            plugin.name.lowercased().contains(lowercaseQuery) ||
            plugin.manifest.description?.lowercased().contains(lowercaseQuery) == true ||
            plugin.command.lowercased().contains(lowercaseQuery)
        }.sorted { $0.name < $1.name }
    }
}