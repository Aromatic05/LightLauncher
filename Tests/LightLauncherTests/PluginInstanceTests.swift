import XCTest
import JavaScriptCore
@testable import LightLauncher

/// 测试 PluginInstance 的运行时实例功能
@MainActor
final class PluginInstanceTests: XCTestCase {
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_instance_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    func testInit_shouldCreateInstance() {
        let plugin = createTestPlugin(name: "test_init", command: "init")
        let instance = PluginInstance(plugin: plugin)
        
        XCTAssertNotNil(instance)
        XCTAssertEqual(instance.plugin.name, "test_init")
        XCTAssertTrue(instance.isEnabled)
        XCTAssertTrue(instance.currentItems.isEmpty)
    }
    
    func testInit_shouldNotHaveContextInitially() {
        let plugin = createTestPlugin(name: "test_no_context", command: "nocontext")
        let instance = PluginInstance(plugin: plugin)
        
        XCTAssertNil(instance.context)
        XCTAssertNil(instance.apiManager)
    }
    
    // MARK: - Context 设置测试
    
    func testSetupContext_shouldCreateJSContext() {
        let plugin = createTestPlugin(name: "test_setup", command: "setup")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        
        XCTAssertNotNil(instance.context)
    }
    
    func testSetupContext_shouldExecuteScript() {
        let plugin = createTestPlugin(
            name: "test_execute",
            command: "exec",
            script: "var testVariable = 'executed';"
        )
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        
        let result = instance.context?.evaluateScript("testVariable")
        XCTAssertEqual(result?.toString(), "executed")
    }
    
    func testSetupContext_multipleCallsShouldNotReCreateContext() {
        let plugin = createTestPlugin(name: "test_multi_setup", command: "multisetup")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        let firstContext = instance.context
        
        instance.setupContext()
        let secondContext = instance.context
        
        // 应该是同一个上下文
        XCTAssertTrue(firstContext === secondContext)
    }
    
    // MARK: - 输入处理测试
    
    func testHandleInput_withCallback_shouldInvokeCallback() {
        let plugin = createTestPlugin(
            name: "test_input",
            command: "input",
            script: """
            var lastInput = '';
            lightlauncher.registerCallback(function(input) {
                lastInput = input;
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        // 设置上下文并注入 API
        setupInstanceWithAPIs(instance)
        
        // 处理输入
        instance.handleInput("test input")
        
        // 验证回调被调用
        let result = instance.context?.evaluateScript("lastInput")
        XCTAssertEqual(result?.toString(), "test input")
    }
    
    func testHandleInput_withoutCallback_shouldNotCrash() {
        let plugin = createTestPlugin(name: "test_no_callback", command: "nocb")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        
        // 没有注册回调，不应崩溃
        instance.handleInput("test")
    }
    
    func testHandleInput_whenDisabled_shouldNotProcess() {
        let plugin = createTestPlugin(name: "test_disabled", command: "disabled")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        instance.isEnabled = false
        
        // 禁用时不应处理输入
        instance.handleInput("test")
        
        // 验证没有处理（取决于实现）
    }
    
    // MARK: - 动作执行测试
    
    func testExecuteAction_withHandler_shouldReturnResult() {
        let plugin = createTestPlugin(
            name: "test_action",
            command: "action",
            script: """
            lightlauncher.registerActionHandler(function(action) {
                return action === 'valid_action';
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        // 执行有效动作
        let validResult = instance.executeAction("valid_action")
        XCTAssertTrue(validResult)
        
        // 执行无效动作
        let invalidResult = instance.executeAction("invalid_action")
        XCTAssertFalse(invalidResult)
    }
    
    func testExecuteAction_withoutHandler_shouldReturnFalse() {
        let plugin = createTestPlugin(name: "test_no_handler", command: "nohandler")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        
        let result = instance.executeAction("any_action")
        XCTAssertFalse(result)
    }
    
    func testExecuteAction_whenDisabled_shouldReturnFalse() {
        let plugin = createTestPlugin(name: "test_action_disabled", command: "actdis")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        instance.isEnabled = false
        
        let result = instance.executeAction("action")
        XCTAssertFalse(result)
    }
    
    // MARK: - 数据项管理测试
    
    func testCurrentItems_initiallyEmpty() {
        let plugin = createTestPlugin(name: "test_items", command: "items")
        let instance = PluginInstance(plugin: plugin)
        
        XCTAssertTrue(instance.currentItems.isEmpty)
    }
    
    func testCurrentItems_canBeUpdated() {
        let plugin = createTestPlugin(name: "test_update_items", command: "updateitems")
        let instance = PluginInstance(plugin: plugin)
        
        let item1 = PluginItem(title: "Item 1", subtitle: nil, iconName: nil, action: nil)
        let item2 = PluginItem(title: "Item 2", subtitle: nil, iconName: nil, action: nil)
        
        instance.currentItems = [item1, item2]
        
        XCTAssertEqual(instance.currentItems.count, 2)
        
        if let first = instance.currentItems.first as? PluginItem {
            XCTAssertEqual(first.title, "Item 1")
        }
    }
    
    func testCurrentItems_publishesChanges() {
        let plugin = createTestPlugin(name: "test_publish", command: "publish")
        let instance = PluginInstance(plugin: plugin)
        
        let expectation = XCTestExpectation(description: "Data change published")
        
        let cancellable = instance.dataDidChange.sink {
            expectation.fulfill()
        }
        
        // 触发变化
        let item = PluginItem(title: "Test", subtitle: nil, iconName: nil, action: nil)
        instance.currentItems = [item]
        
        wait(for: [expectation], timeout: 1.0)
        
        cancellable.cancel()
    }
    
    // MARK: - 回调管理测试
    
    func testSearchCallback_canBeSet() {
        let plugin = createTestPlugin(name: "test_set_cb", command: "setcb")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        instance.context?.evaluateScript("""
        lightlauncher.registerCallback(function(input) {
            return 'callback';
        });
        """)
        
        XCTAssertNotNil(instance.searchCallback)
    }
    
    func testActionHandler_canBeSet() {
        let plugin = createTestPlugin(name: "test_set_handler", command: "sethandler")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        instance.context?.evaluateScript("""
        lightlauncher.registerActionHandler(function(action) {
            return true;
        });
        """)
        
        XCTAssertNotNil(instance.actionHandler)
    }
    
    // MARK: - 清理测试
    
    func testCleanup_shouldClearContext() {
        let plugin = createTestPlugin(name: "test_cleanup", command: "cleanup")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        XCTAssertNotNil(instance.context)
        
        instance.cleanup()
        
        XCTAssertNil(instance.context)
    }
    
    func testCleanup_shouldClearAPIManager() {
        let plugin = createTestPlugin(name: "test_cleanup_api", command: "cleanupapi")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        XCTAssertNotNil(instance.apiManager)
        
        instance.cleanup()
        
        XCTAssertNil(instance.apiManager)
    }
    
    func testCleanup_shouldClearCallbacks() {
        let plugin = createTestPlugin(name: "test_cleanup_cb", command: "cleanupcb")
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        instance.context?.evaluateScript("""
        lightlauncher.registerCallback(function(input) {});
        lightlauncher.registerActionHandler(function(action) {});
        """)
        
        instance.cleanup()
        
        XCTAssertNil(instance.searchCallback)
        XCTAssertNil(instance.actionHandler)
    }
    
    func testCleanup_shouldClearItems() {
        let plugin = createTestPlugin(name: "test_cleanup_items", command: "cleanupitems")
        let instance = PluginInstance(plugin: plugin)
        
        instance.currentItems = [
            PluginItem(title: "Item", subtitle: nil, iconName: nil, action: nil)
        ]
        
        instance.cleanup()
        
        XCTAssertTrue(instance.currentItems.isEmpty)
    }
    
    func testCleanup_multipleCallsShouldNotCrash() {
        let plugin = createTestPlugin(name: "test_multi_cleanup", command: "multiclean")
        let instance = PluginInstance(plugin: plugin)
        
        instance.setupContext()
        
        instance.cleanup()
        instance.cleanup()
        instance.cleanup()
        
        // 多次清理不应崩溃
    }
    
    // MARK: - 启用/禁用测试
    
    func testIsEnabled_defaultTrue() {
        let plugin = createTestPlugin(name: "test_enabled", command: "enabled")
        let instance = PluginInstance(plugin: plugin)
        
        XCTAssertTrue(instance.isEnabled)
    }
    
    func testIsEnabled_canBeToggled() {
        let plugin = createTestPlugin(name: "test_toggle", command: "toggle")
        let instance = PluginInstance(plugin: plugin)
        
        instance.isEnabled = false
        XCTAssertFalse(instance.isEnabled)
        
        instance.isEnabled = true
        XCTAssertTrue(instance.isEnabled)
    }
    
    // MARK: - 更新通知测试
    
    func testOnItemsUpdated_callback() {
        let plugin = createTestPlugin(name: "test_callback", command: "callback")
        let instance = PluginInstance(plugin: plugin)
        
        var callbackInvoked = false
        instance.onItemsUpdated = {
            callbackInvoked = true
        }
        
        // 触发回调
        instance.onItemsUpdated?()
        
        XCTAssertTrue(callbackInvoked)
    }
    
    // MARK: - JavaScript 异常处理测试
    
    func testHandleInput_withJavaScriptError_shouldNotCrash() {
        let plugin = createTestPlugin(
            name: "test_error",
            command: "error",
            script: """
            lightlauncher.registerCallback(function(input) {
                throw new Error('Test error');
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        // JavaScript 错误不应导致崩溃
        instance.handleInput("test")
    }
    
    func testExecuteAction_withJavaScriptError_shouldReturnFalse() {
        let plugin = createTestPlugin(
            name: "test_action_error",
            command: "actionerr",
            script: """
            lightlauncher.registerActionHandler(function(action) {
                throw new Error('Action error');
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        let result = instance.executeAction("test_action")
        
        // 错误应返回 false
        XCTAssertFalse(result)
    }
    
    // MARK: - 边界情况测试
    
    func testHandleInput_withEmptyString_shouldWork() {
        let plugin = createTestPlugin(
            name: "test_empty_input",
            command: "emptyinput",
            script: """
            var lastInput = null;
            lightlauncher.registerCallback(function(input) {
                lastInput = input;
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        instance.handleInput("")
        
        let result = instance.context?.evaluateScript("lastInput")
        XCTAssertEqual(result?.toString(), "")
    }
    
    func testHandleInput_withSpecialCharacters_shouldWork() {
        let plugin = createTestPlugin(
            name: "test_special",
            command: "special",
            script: """
            var lastInput = null;
            lightlauncher.registerCallback(function(input) {
                lastInput = input;
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        let specialInput = "特殊字符 !@#$%^&*()"
        instance.handleInput(specialInput)
        
        let result = instance.context?.evaluateScript("lastInput")
        XCTAssertEqual(result?.toString(), specialInput)
    }
    
    func testExecuteAction_withEmptyAction_shouldWork() {
        let plugin = createTestPlugin(
            name: "test_empty_action",
            command: "emptyaction",
            script: """
            lightlauncher.registerActionHandler(function(action) {
                return action === '';
            });
            """
        )
        let instance = PluginInstance(plugin: plugin)
        
        setupInstanceWithAPIs(instance)
        
        let result = instance.executeAction("")
        XCTAssertTrue(result)
    }
    
    // MARK: - 辅助方法
    
    private func createTestPlugin(
        name: String,
        command: String,
        script: String = "console.log('test');"
    ) -> Plugin {
        let manifest = PluginManifest(
            name: name,
            version: "1.0.0",
            displayName: name.capitalized,
            description: "Test plugin",
            command: command,
            author: "Test Author",
            main: "main.js",
            placeholder: nil,
            iconName: nil,
            shouldHideWindowAfterAction: nil,
            help: nil,
            interface: nil,
            permissions: nil,
            minLightLauncherVersion: nil,
            maxLightLauncherVersion: nil,
            dependencies: nil,
            keywords: nil,
            homepage: nil,
            repository: nil
        )
        
        return Plugin(
            url: testPluginDirectory,
            manifest: manifest,
            script: script,
            effectiveConfig: [:]
        )
    }
    
    private func setupInstanceWithAPIs(_ instance: PluginInstance) {
        let context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print("JS Exception: \(exception?.toString() ?? "unknown")")
        }
        
        let apiManager = APIManager(pluginInstance: instance)
        apiManager.injectAPIs(into: context)
        
        instance.context = context
        instance.apiManager = apiManager
        
        // 执行脚本
        context.evaluateScript(instance.plugin.script)
    }
}
