import XCTest
@testable import LightLauncher

/// 测试 PluginManager 的插件注册、加载和管理功能
@MainActor
final class PluginManagerTests: XCTestCase {
    var pluginManager: PluginManager!
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        pluginManager = PluginManager.shared
        
        // 创建临时测试插件目录
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_plugins_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // 清理测试插件目录
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    func testLoadAllPlugins_shouldLoadExistingPlugins() async {
        // 使用项目中的 TestPlugins
        await pluginManager.loadAllPlugins()
        
        // 验证至少加载了一些插件
        XCTAssertGreaterThan(pluginManager.plugins.count, 0, "应该加载了至少一个插件")
    }
    
    func testRegisterPlugin_shouldAddPluginToRegistry() {
        // 创建测试插件
        let manifest = createTestManifest(name: "test_plugin", command: "test")
        let plugin = Plugin(
            url: testPluginDirectory,
            manifest: manifest,
            script: "console.log('test');",
            effectiveConfig: [:]
        )
        
        // 注册插件
        pluginManager.register(plugin)
        
        // 验证插件已注册
        XCTAssertNotNil(pluginManager.plugins["test_plugin"])
        XCTAssertEqual(pluginManager.plugins["test_plugin"]?.name, "test_plugin")
    }
    
    func testUnregisterPlugin_shouldRemovePluginFromRegistry() {
        // 先注册一个插件
        let manifest = createTestManifest(name: "test_plugin", command: "test")
        let plugin = Plugin(
            url: testPluginDirectory,
            manifest: manifest,
            script: "console.log('test');",
            effectiveConfig: [:]
        )
        pluginManager.register(plugin)
        
        // 注销插件
        pluginManager.unregister("test_plugin")
        
        // 验证插件已被移除
        XCTAssertNil(pluginManager.plugins["test_plugin"])
    }
    
    func testGetPlugin_shouldReturnCorrectPlugin() async {
        await pluginManager.loadAllPlugins()
        
        // 假设已加载 calc 插件
        if let calcPlugin = pluginManager.plugins.values.first(where: { $0.command == "calc" }) {
            let retrieved = pluginManager.getPlugin(for: "calc")
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.name, calcPlugin.name)
        }
    }
    
    func testGetEnabledPlugins_shouldOnlyReturnEnabledPlugins() {
        // 创建启用和禁用的插件
        let enabledManifest = createTestManifest(name: "enabled_plugin", command: "enabled")
        let enabledPlugin = Plugin(
            url: testPluginDirectory,
            manifest: enabledManifest,
            script: "console.log('enabled');",
            effectiveConfig: [:]
        )
        enabledPlugin.isEnabled = true
        
        let disabledManifest = createTestManifest(name: "disabled_plugin", command: "disabled")
        let disabledPlugin = Plugin(
            url: testPluginDirectory,
            manifest: disabledManifest,
            script: "console.log('disabled');",
            effectiveConfig: [:]
        )
        disabledPlugin.isEnabled = false
        
        pluginManager.register(enabledPlugin)
        pluginManager.register(disabledPlugin)
        
        // 获取启用的插件
        let enabledPlugins = pluginManager.getEnabledPlugins()
        
        // 验证只包含启用的插件
        XCTAssertTrue(enabledPlugins.contains { $0.name == "enabled_plugin" })
        XCTAssertFalse(enabledPlugins.contains { $0.name == "disabled_plugin" })
    }
    
    func testEnableDisablePlugin_shouldChangeEnabledState() {
        let manifest = createTestManifest(name: "toggle_plugin", command: "toggle")
        let plugin = Plugin(
            url: testPluginDirectory,
            manifest: manifest,
            script: "console.log('toggle');",
            effectiveConfig: [:]
        )
        plugin.isEnabled = true
        pluginManager.register(plugin)
        
        // 禁用插件
        pluginManager.disablePlugin("toggle_plugin")
        XCTAssertFalse(pluginManager.plugins["toggle_plugin"]?.isEnabled ?? true)
        
        // 启用插件
        pluginManager.enablePlugin("toggle_plugin")
        XCTAssertTrue(pluginManager.plugins["toggle_plugin"]?.isEnabled ?? false)
    }
    
    // MARK: - 边界情况测试
    
    func testRegisterPlugin_withDuplicateName_shouldReplaceExisting() {
        let manifest1 = createTestManifest(name: "dup_plugin", command: "dup", version: "1.0.0")
        let plugin1 = Plugin(
            url: testPluginDirectory,
            manifest: manifest1,
            script: "console.log('v1');",
            effectiveConfig: [:]
        )
        
        let manifest2 = createTestManifest(name: "dup_plugin", command: "dup", version: "2.0.0")
        let plugin2 = Plugin(
            url: testPluginDirectory,
            manifest: manifest2,
            script: "console.log('v2');",
            effectiveConfig: [:]
        )
        
        pluginManager.register(plugin1)
        pluginManager.register(plugin2)
        
        // 验证新插件替换了旧插件
        XCTAssertEqual(pluginManager.plugins["dup_plugin"]?.version, "2.0.0")
    }
    
    func testGetPlugin_withNonexistentCommand_shouldReturnNil() {
        let result = pluginManager.getPlugin(for: "nonexistent_command_xyz")
        XCTAssertNil(result)
    }
    
    func testUnregisterPlugin_withNonexistentName_shouldNotCrash() {
        // 应该不会崩溃
        pluginManager.unregister("nonexistent_plugin_xyz")
    }
    
    // MARK: - 辅助方法
    
    private func createTestManifest(
        name: String,
        command: String,
        version: String = "1.0.0",
        description: String = "Test plugin"
    ) -> PluginManifest {
        return PluginManifest(
            name: name,
            version: version,
            displayName: name.capitalized,
            description: description,
            command: command,
            author: "Test Author",
            main: "main.js",
            placeholder: "Enter \(command)...",
            iconName: "gear",
            shouldHideWindowAfterAction: true,
            help: ["Test help"],
            interface: nil,
            permissions: nil,
            minLightLauncherVersion: nil,
            maxLightLauncherVersion: nil,
            dependencies: nil,
            keywords: nil,
            homepage: nil,
            repository: nil
        )
    }
}
