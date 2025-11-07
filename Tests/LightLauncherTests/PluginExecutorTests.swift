import XCTest
import JavaScriptCore
@testable import LightLauncher

/// 测试 PluginExecutor 的插件实例管理功能
@MainActor
final class PluginExecutorTests: XCTestCase {
    var executor: PluginExecutor!
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        executor = PluginExecutor.shared
        
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_executor_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // 清理所有实例
        executor.destroyAllInstances()
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - 实例创建测试
    
    func testCreateInstance_withValidPlugin_shouldSucceed() {
        let plugin = createTestPlugin(name: "test_create", command: "create")
        
        let instance = executor.createInstance(for: plugin)
        
        XCTAssertNotNil(instance)
        XCTAssertEqual(instance?.plugin.name, "test_create")
        XCTAssertTrue(executor.hasInstance(for: "test_create"))
    }
    
    func testCreateInstance_shouldNotCreateDuplicates() {
        let plugin = createTestPlugin(name: "test_dup", command: "dup")
        
        let instance1 = executor.createInstance(for: plugin)
        let instance2 = executor.createInstance(for: plugin)
        
        // 应返回同一个实例
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testCreateInstance_withJavaScriptContext_shouldSetupContext() {
        let plugin = createTestPlugin(
            name: "test_js",
            command: "js",
            script: "var testVar = 42;"
        )
        
        let instance = executor.createInstance(for: plugin)
        
        XCTAssertNotNil(instance?.context)
        
        // 验证脚本已执行
        let result = instance?.context?.evaluateScript("testVar")
        XCTAssertEqual(result?.toInt32(), 42)
    }
    
    // MARK: - 实例获取测试
    
    func testGetInstance_withExistingInstance_shouldReturnInstance() {
        let plugin = createTestPlugin(name: "test_get", command: "get")
        
        let created = executor.createInstance(for: plugin)
        let retrieved = executor.getInstance(for: "test_get")
        
        XCTAssertTrue(created === retrieved)
    }
    
    func testGetInstance_withNonexistentInstance_shouldReturnNil() {
        let retrieved = executor.getInstance(for: "nonexistent_plugin")
        
        XCTAssertNil(retrieved)
    }
    
    func testHasInstance_withExistingInstance_shouldReturnTrue() {
        let plugin = createTestPlugin(name: "test_has", command: "has")
        _ = executor.createInstance(for: plugin)
        
        XCTAssertTrue(executor.hasInstance(for: "test_has"))
    }
    
    func testHasInstance_withNonexistentInstance_shouldReturnFalse() {
        XCTAssertFalse(executor.hasInstance(for: "nonexistent_plugin"))
    }
    
    // MARK: - 实例销毁测试
    
    func testDestroyInstance_shouldRemoveInstance() {
        let plugin = createTestPlugin(name: "test_destroy", command: "destroy")
        _ = executor.createInstance(for: plugin)
        
        XCTAssertTrue(executor.hasInstance(for: "test_destroy"))
        
        executor.destroyInstance(for: "test_destroy")
        
        XCTAssertFalse(executor.hasInstance(for: "test_destroy"))
        XCTAssertNil(executor.getInstance(for: "test_destroy"))
    }
    
    func testDestroyInstance_shouldCallCleanup() {
        let plugin = createTestPlugin(name: "test_cleanup", command: "cleanup")
        let instance = executor.createInstance(for: plugin)
        
        XCTAssertNotNil(instance?.context)
        
        executor.destroyInstance(for: "test_cleanup")
        
        // 验证上下文被清理
        XCTAssertNil(instance?.context)
    }
    
    func testDestroyInstance_withNonexistentInstance_shouldNotCrash() {
        // 应该不会崩溃
        executor.destroyInstance(for: "nonexistent_plugin")
    }
    
    func testDestroyAllInstances_shouldRemoveAllInstances() {
        // 创建多个实例
        let plugin1 = createTestPlugin(name: "plugin1", command: "p1")
        let plugin2 = createTestPlugin(name: "plugin2", command: "p2")
        let plugin3 = createTestPlugin(name: "plugin3", command: "p3")
        
        _ = executor.createInstance(for: plugin1)
        _ = executor.createInstance(for: plugin2)
        _ = executor.createInstance(for: plugin3)
        
        XCTAssertEqual(executor.getAllInstances().count, 3)
        
        executor.destroyAllInstances()
        
        XCTAssertEqual(executor.getAllInstances().count, 0)
        XCTAssertFalse(executor.hasInstance(for: "plugin1"))
        XCTAssertFalse(executor.hasInstance(for: "plugin2"))
        XCTAssertFalse(executor.hasInstance(for: "plugin3"))
    }
    
    // MARK: - 实例重建测试
    
    func testRecreateInstance_shouldCreateNewInstance() {
        let plugin = createTestPlugin(name: "test_recreate", command: "recreate")
        
        let instance1 = executor.createInstance(for: plugin)
        XCTAssertNotNil(instance1)
        
        let instance2 = executor.recreateInstance(for: plugin)
        XCTAssertNotNil(instance2)
        
        // 应该是不同的实例
        XCTAssertFalse(instance1 === instance2)
    }
    
    func testRecreateInstance_shouldCleanupOldInstance() {
        let plugin = createTestPlugin(
            name: "test_recreate_cleanup",
            command: "rclean",
            script: "var counter = 0;"
        )
        
        let instance1 = executor.createInstance(for: plugin)
        instance1?.context?.evaluateScript("counter = 10;")
        
        let value1 = instance1?.context?.evaluateScript("counter")
        XCTAssertEqual(value1?.toInt32(), 10)
        
        // 重建实例
        let instance2 = executor.recreateInstance(for: plugin)
        
        // 新实例应该有全新的上下文
        let value2 = instance2?.context?.evaluateScript("counter")
        XCTAssertEqual(value2?.toInt32(), 0)
    }
    
    // MARK: - 多实例管理测试
    
    func testGetAllInstances_shouldReturnAllActiveInstances() {
        let plugin1 = createTestPlugin(name: "multi1", command: "m1")
        let plugin2 = createTestPlugin(name: "multi2", command: "m2")
        let plugin3 = createTestPlugin(name: "multi3", command: "m3")
        
        _ = executor.createInstance(for: plugin1)
        _ = executor.createInstance(for: plugin2)
        _ = executor.createInstance(for: plugin3)
        
        let instances = executor.getAllInstances()
        
        XCTAssertEqual(instances.count, 3)
        
        let names = Set(instances.map { $0.plugin.name })
        XCTAssertTrue(names.contains("multi1"))
        XCTAssertTrue(names.contains("multi2"))
        XCTAssertTrue(names.contains("multi3"))
    }
    
    func testGetAllInstances_withNoInstances_shouldReturnEmpty() {
        let instances = executor.getAllInstances()
        
        XCTAssertTrue(instances.isEmpty)
    }
    
    func testGetAllInstances_afterDestroy_shouldNotIncludeDestroyedInstances() {
        let plugin1 = createTestPlugin(name: "persist1", command: "pr1")
        let plugin2 = createTestPlugin(name: "persist2", command: "pr2")
        
        _ = executor.createInstance(for: plugin1)
        _ = executor.createInstance(for: plugin2)
        
        XCTAssertEqual(executor.getAllInstances().count, 2)
        
        executor.destroyInstance(for: "persist1")
        
        let instances = executor.getAllInstances()
        XCTAssertEqual(instances.count, 1)
        XCTAssertEqual(instances.first?.plugin.name, "persist2")
    }
    
    // MARK: - JavaScript 上下文测试
    
    func testCreateInstance_shouldInjectAPIs() {
        let plugin = createTestPlugin(name: "test_api", command: "api")
        
        let instance = executor.createInstance(for: plugin)
        
        // 验证 lightlauncher 对象被注入
        let lightlauncher = instance?.context?.evaluateScript("typeof lightlauncher")
        XCTAssertEqual(lightlauncher?.toString(), "object")
    }
    
    func testCreateInstance_shouldHandleJavaScriptExceptions() {
        let plugin = createTestPlugin(
            name: "test_exception",
            command: "exception",
            script: "throw new Error('Test error');"
        )
        
        // 应该能创建实例，即使脚本抛出异常
        let instance = executor.createInstance(for: plugin)
        
        XCTAssertNotNil(instance)
        XCTAssertNotNil(instance?.context)
    }
    
    func testCreateInstance_shouldExecuteScript() {
        let plugin = createTestPlugin(
            name: "test_exec",
            command: "exec",
            script: """
            var executed = true;
            var result = 'Hello from plugin';
            """
        )
        
        let instance = executor.createInstance(for: plugin)
        
        let executed = instance?.context?.evaluateScript("executed")
        XCTAssertTrue(executed?.toBool() ?? false)
        
        let result = instance?.context?.evaluateScript("result")
        XCTAssertEqual(result?.toString(), "Hello from plugin")
    }
    
    // MARK: - 边界情况测试
    
    func testCreateInstance_withEmptyScript_shouldStillCreateInstance() {
        let plugin = createTestPlugin(
            name: "empty_script",
            command: "empty",
            script: ""
        )
        
        let instance = executor.createInstance(for: plugin)
        
        // 即使脚本为空，也应该能创建实例
        XCTAssertNotNil(instance)
        XCTAssertNotNil(instance?.context)
    }
    
    func testInstanceIsolation_instancesShouldNotShareContext() {
        let plugin1 = createTestPlugin(
            name: "isolated1",
            command: "iso1",
            script: "var shared = 'plugin1';"
        )
        let plugin2 = createTestPlugin(
            name: "isolated2",
            command: "iso2",
            script: "var shared = 'plugin2';"
        )
        
        let instance1 = executor.createInstance(for: plugin1)
        let instance2 = executor.createInstance(for: plugin2)
        
        // 每个实例应该有独立的上下文
        let value1 = instance1?.context?.evaluateScript("shared")
        let value2 = instance2?.context?.evaluateScript("shared")
        
        XCTAssertEqual(value1?.toString(), "plugin1")
        XCTAssertEqual(value2?.toString(), "plugin2")
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
}
