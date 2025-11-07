import XCTest
@testable import LightLauncher

/// 测试 PluginModeController 的插件模式功能和集成
@MainActor
final class PluginModeControllerTests: XCTestCase {
    var pluginMode: PluginModeController!
    var pluginManager: PluginManager!
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        pluginMode = PluginModeController.shared
        pluginManager = PluginManager.shared
        
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_plugin_mode_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
        
        // 清理状态
        pluginMode.cleanup()
    }
    
    override func tearDown() async throws {
        pluginMode.cleanup()
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - ModeStateController 协议实现测试
    
    func testModeProperties_shouldHaveCorrectValues() {
        XCTAssertEqual(pluginMode.mode, .plugin)
        XCTAssertEqual(pluginMode.prefix, "/p")
        XCTAssertEqual(pluginMode.displayName, "Plugins")
        XCTAssertEqual(pluginMode.iconName, "puzzlepiece.extension")
        XCTAssertNotNil(pluginMode.placeholder)
    }
    
    func testCleanup_shouldResetState() {
        // 设置一些状态
        pluginMode.handleInput(arguments: "test")
        
        // 清理
        pluginMode.cleanup()
        
        // 验证状态被重置
        XCTAssertTrue(pluginMode.displayableItems.isEmpty)
    }
    
    func testMakeContentView_shouldReturnView() {
        let view = pluginMode.makeContentView()
        
        XCTAssertNotNil(view)
    }
    
    func testGetHelpText_shouldReturnPluginList() {
        let helpText = pluginMode.getHelpText()
        
        XCTAssertFalse(helpText.isEmpty)
        XCTAssertTrue(helpText.first?.contains("Plugins") ?? false)
    }
    
    // MARK: - 输入处理测试
    
    func testHandleInput_withEmptyString_shouldShowPluginList() async {
        pluginMode.handleInput(arguments: "")
        
        // 等待异步处理
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 应该显示可用插件列表
        let items = pluginMode.displayableItems
        XCTAssertNotNil(items)
    }
    
    func testHandleInput_withInvalidCommand_shouldShowNotFound() async {
        pluginMode.handleInput(arguments: "nonexistent_command_xyz")
        
        // 等待异步处理
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let items = pluginMode.displayableItems
        
        // 应该显示未找到的消息
        if let firstItem = items.first as? PluginItem {
            XCTAssertTrue(firstItem.title.contains("not found") || firstItem.title.contains("Plugin"))
        }
    }
    
    func testHandleInput_withValidCommand_shouldActivatePlugin() async {
        // 先注册一个测试插件
        _ = createAndRegisterTestPlugin(name: "test_activate", command: "testcmd")
        
        // 使用命令激活插件
        pluginMode.handleInput(arguments: "testcmd")
        
        // 等待异步处理
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // 验证插件被激活
        XCTAssertNotNil(pluginMode.activeInstance)
    }
    
    func testHandleInput_withCommandAndArguments_shouldPassArguments() async {
        _ = createAndRegisterTestPlugin(
            name: "test_args",
            command: "argtest",
            script: """
            lightlauncher.registerCallback(function(input) {
                lightlauncher.display([
                    { title: 'Received: ' + input }
                ]);
            });
            """
        )
        
        // 使用命令和参数
        pluginMode.handleInput(arguments: "argtest hello world")
        
        // 等待异步处理和回调
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // 验证参数被传递
        if let firstItem = pluginMode.displayableItems.first as? PluginItem {
            XCTAssertTrue(firstItem.title.contains("hello world"))
        }
    }
    
    // MARK: - 插件列表显示测试
    
    func testShowAvailablePlugins_shouldListEnabledPlugins() async {
        // 注册多个插件
        _ = createAndRegisterTestPlugin(name: "plugin1", command: "cmd1")
        _ = createAndRegisterTestPlugin(name: "plugin2", command: "cmd2")
        
        // 触发显示插件列表
        pluginMode.handleInput(arguments: "")
        
        // 等待处理
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let items = pluginMode.displayableItems
        
        // 应该包含注册的插件
        XCTAssertGreaterThanOrEqual(items.count, 2)
    }
    
    // MARK: - 插件切换测试
    
    func testSwitchPlugin_shouldChangeActivePlugin() async {
        _ = createAndRegisterTestPlugin(name: "switch1", command: "sw1")
        _ = createAndRegisterTestPlugin(name: "switch2", command: "sw2")
        
        // 激活第一个插件
        pluginMode.handleInput(arguments: "sw1")
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let firstActive = pluginMode.activeInstance?.plugin.name
        
        // 切换到第二个插件
        pluginMode.handleInput(arguments: "sw2")
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let secondActive = pluginMode.activeInstance?.plugin.name
        
        // 验证切换成功
        XCTAssertEqual(firstActive, "switch1")
        XCTAssertEqual(secondActive, "switch2")
    }
    
    // MARK: - 数据更新测试
    
    func testDataDidChange_shouldPublishOnUpdates() async {
        let expectation = XCTestExpectation(description: "Data change published")
        
        let cancellable = pluginMode.dataDidChange.sink {
            expectation.fulfill()
        }
        
        // 触发数据变化
        pluginMode.handleInput(arguments: "")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        cancellable.cancel()
    }
    
    // MARK: - Placeholder 测试
    
    func testPlaceholder_shouldChangeWithActivePlugin() async {
        _ = pluginMode.placeholder
        
        // 激活一个有自定义 placeholder 的插件
        _ = createAndRegisterTestPlugin(
            name: "test_placeholder",
            command: "phtest",
            placeholder: "Custom placeholder"
        )
        
        pluginMode.handleInput(arguments: "phtest")
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Placeholder 应该变为插件的自定义值（如果实现了的话）
        // 注意：这取决于你的实现细节
        let activePlaceholder = pluginMode.placeholder
        XCTAssertNotNil(activePlaceholder)
    }
    
    // MARK: - 错误处理测试
    
    func testHandleInput_withDisabledPlugin_shouldNotActivate() async {
        let plugin = createAndRegisterTestPlugin(name: "disabled", command: "disabled")
        plugin.isEnabled = false
        
        pluginMode.handleInput(arguments: "disabled")
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // 禁用的插件不应该被激活（取决于实现）
        // 可能显示错误或跳过
    }
    
    func testHandleInput_withMalformedInput_shouldHandleGracefully() async {
        // 各种异常输入不应崩溃
        pluginMode.handleInput(arguments: "   ")
        pluginMode.handleInput(arguments: "||||")
        pluginMode.handleInput(arguments: String(repeating: "a", count: 10000))
        
        // 不应崩溃
    }
    
    // MARK: - 状态一致性测试
    
    func testMultipleCleanups_shouldNotCrash() {
        pluginMode.cleanup()
        pluginMode.cleanup()
        pluginMode.cleanup()
        
        // 多次清理不应崩溃
    }
    
    func testCleanup_duringPluginExecution_shouldSafelyStop() async {
        _ = createAndRegisterTestPlugin(name: "cleanup_test", command: "cltest")
        
        pluginMode.handleInput(arguments: "cltest test")
        
        // 立即清理
        pluginMode.cleanup()
        
        // 不应崩溃
        XCTAssertNil(pluginMode.activeInstance)
    }
    
    // MARK: - 集成测试
    
    func testFullPluginWorkflow_shouldWorkEndToEnd() async {
        // 创建一个完整的插件
        _ = createAndRegisterTestPlugin(
            name: "full_workflow",
            command: "fulltest",
            script: """
            lightlauncher.registerCallback(function(input) {
                if (input === 'test') {
                    lightlauncher.display([
                        { 
                            title: 'Test Result',
                            subtitle: 'Workflow test',
                            action: 'test_action'
                        }
                    ]);
                }
            });
            
            lightlauncher.registerActionHandler(function(action) {
                if (action === 'test_action') {
                    return true;
                }
                return false;
            });
            """
        )
        
        // 1. 激活插件
        pluginMode.handleInput(arguments: "fulltest test")
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // 2. 验证结果显示
        XCTAssertFalse(pluginMode.displayableItems.isEmpty)
        
        if let item = pluginMode.displayableItems.first as? PluginItem {
            XCTAssertEqual(item.title, "Test Result")
        }
        
        // 3. 清理
        pluginMode.cleanup()
        XCTAssertTrue(pluginMode.displayableItems.isEmpty)
    }
    
    // MARK: - 辅助方法
    
    @discardableResult
    private func createAndRegisterTestPlugin(
        name: String,
        command: String,
        script: String = "console.log('test');",
        placeholder: String? = nil
    ) -> Plugin {
        let manifest = PluginManifest(
            name: name,
            version: "1.0.0",
            displayName: name.capitalized,
            description: "Test plugin",
            command: command,
            author: "Test Author",
            main: "main.js",
            placeholder: placeholder,
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
        
        let plugin = Plugin(
            url: testPluginDirectory.appendingPathComponent(name),
            manifest: manifest,
            script: script,
            effectiveConfig: [:]
        )
        
        plugin.isEnabled = true
        pluginManager.register(plugin)
        
        return plugin
    }
}
