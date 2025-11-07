import XCTest
import JavaScriptCore
@testable import LightLauncher

/// 测试 APIManager 的 API 注入和权限控制功能
@MainActor
final class APIManagerTests: XCTestCase {
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_api_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - API 注入测试
    
    func testInjectAPIs_shouldCreateLightlauncherObject() {
        let (_, context, _) = createTestSetup()
        
        let lightlauncher = context.evaluateScript("typeof lightlauncher")
        XCTAssertEqual(lightlauncher?.toString(), "object")
    }
    
    func testInjectCoreAPIs_shouldProvideBasicFunctions() {
        let (_, context, _) = createTestSetup()
        
        // 验证核心 API 存在
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.display")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.log")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.registerCallback")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.getConfig")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.getDataPath")?.toString(), "function")
    }
    
    func testInjectFileAPIs_shouldProvideFileFunctions() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileRead),
            PluginPermissionSpec(type: .fileWrite)
        ])
        
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.readFile")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.writeFile")?.toString(), "function")
    }
    
    func testInjectClipboardAPIs_shouldProvideClipboardFunctions() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .clipboard)
        ])
        
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.readClipboard")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.writeClipboard")?.toString(), "function")
    }
    
    func testInjectNetworkAPIs_shouldProvideNetworkFunctions() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .network)
        ])
        
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.networkRequest")?.toString(), "function")
    }
    
    func testInjectPermissionAPIs_shouldProvidePermissionCheckFunctions() {
        let (_, context, _) = createTestSetup()
        
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.hasFileWritePermission")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.hasNetworkPermission")?.toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof lightlauncher.hasClipboardPermission")?.toString(), "function")
    }
    
    // MARK: - 核心 API 功能测试
    
    func testLogAPI_shouldNotCrash() {
        let (_, context, _) = createTestSetup()
        
        // 调用 log 不应崩溃
        context.evaluateScript("lightlauncher.log('Test log message');")
    }
    
    func testGetConfigAPI_shouldReturnConfig() {
        let config = ["testKey": "testValue"]
        let (_, context, _) = createTestSetup(config: config)
        
        let result = context.evaluateScript("lightlauncher.getConfig();")
        let configDict = result?.toDictionary() as? [String: String]
        
        XCTAssertEqual(configDict?["testKey"], "testValue")
    }
    
    func testGetDataPathAPI_shouldReturnPath() {
        let (_, context, plugin) = createTestSetup()
        
        let result = context.evaluateScript("lightlauncher.getDataPath();")
        let path = result?.toString()
        
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains(plugin.name) ?? false)
        XCTAssertTrue(path?.contains("LightLauncher/data") ?? false)
    }
    
    func testDisplayAPI_shouldUpdatePluginItems() {
        let (instance, context, _) = createTestSetup()
        
        // 调用 display API
        context.evaluateScript("""
        lightlauncher.display([
            { title: 'Item 1', subtitle: 'Subtitle 1', action: 'action1' },
            { title: 'Item 2', subtitle: 'Subtitle 2', action: 'action2' }
        ]);
        """)
        
        // 等待异步更新
        let expectation = XCTestExpectation(description: "Items updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(instance.currentItems.count, 2)
            
            if let item1 = instance.currentItems.first as? PluginItem {
                XCTAssertEqual(item1.title, "Item 1")
                XCTAssertEqual(item1.subtitle, "Subtitle 1")
                XCTAssertEqual(item1.action, "action1")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRegisterCallbackAPI_shouldSetCallback() {
        let (instance, context, _) = createTestSetup()
        
        context.evaluateScript("""
        lightlauncher.registerCallback(function(input) {
            return 'callback executed';
        });
        """)
        
        XCTAssertNotNil(instance.searchCallback)
    }
    
    // MARK: - 文件 API 权限测试
    
    func testReadFile_withoutPermission_shouldReturnNil() {
        let (_, context, _) = createTestSetup(permissions: [])
        
        // 尝试读取文件（无权限）
        let result = context.evaluateScript("lightlauncher.readFile('/tmp/test.txt');")
        
        XCTAssertTrue(result?.isNull ?? false || result?.isUndefined ?? false)
    }
    
    func testWriteFile_withoutPermission_shouldReturnFalse() {
        let (_, context, _) = createTestSetup(permissions: [])
        
        // 尝试写入文件（无权限）
        let result = context.evaluateScript("""
        lightlauncher.writeFile({path: '/tmp/test.txt', content: 'test'});
        """)
        
        XCTAssertEqual(result?.toBool(), false)
    }
    
    func testReadFile_withPermission_shouldSucceed() throws {
        // 创建测试文件
        let testFilePath = testPluginDirectory.appendingPathComponent("test_read.txt").path
        try "Test content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileRead)
        ])
        
        // 读取文件
        let script = "lightlauncher.readFile('\(testFilePath)');"
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result?.toString(), "Test content")
    }
    
    func testWriteFile_withPermission_shouldSucceed() {
        let testFilePath = testPluginDirectory.appendingPathComponent("test_write.txt").path
        
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileWrite)
        ])
        
        // 写入文件
        let script = """
        lightlauncher.writeFile({
            path: '\(testFilePath)',
            content: 'Written content'
        });
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result?.toBool(), true)
        
        // 验证文件确实被写入
        let content = try? String(contentsOfFile: testFilePath, encoding: .utf8)
        XCTAssertEqual(content, "Written content")
    }
    
    func testFileAPI_inDataDirectory_shouldNotRequirePermission() {
        let (_, context, _) = createTestSetup(permissions: [])
        
        // 获取数据目录
        let dataPathResult = context.evaluateScript("lightlauncher.getDataPath();")
        let dataPath = dataPathResult?.toString() ?? ""
        let testFilePath = "\(dataPath)/test.txt"
        
        // 在数据目录中写入应该不需要额外权限
        let writeScript = """
        lightlauncher.writeFile({
            path: '\(testFilePath)',
            content: 'Data directory content'
        });
        """
        let writeResult = context.evaluateScript(writeScript)
        
        XCTAssertEqual(writeResult?.toBool(), true)
        
        // 读取也应该成功
        let readScript = "lightlauncher.readFile('\(testFilePath)');"
        let readResult = context.evaluateScript(readScript)
        
        XCTAssertEqual(readResult?.toString(), "Data directory content")
    }
    
    // MARK: - 剪贴板 API 权限测试
    
    func testReadClipboard_withoutPermission_shouldReturnNil() {
        let (_, context, _) = createTestSetup(permissions: [])
        
        let result = context.evaluateScript("lightlauncher.readClipboard();")
        
        XCTAssertTrue(result?.isNull ?? false || result?.isUndefined ?? false)
    }
    
    func testWriteClipboard_withoutPermission_shouldReturnFalse() {
        let (_, context, _) = createTestSetup(permissions: [])
        
        let result = context.evaluateScript("lightlauncher.writeClipboard('test');")
        
        XCTAssertEqual(result?.toBool(), false)
    }
    
    func testWriteClipboard_withPermission_shouldSucceed() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .clipboard)
        ])
        
        let result = context.evaluateScript("lightlauncher.writeClipboard('Clipboard test');")
        
        XCTAssertEqual(result?.toBool(), true)
        
        // 验证剪贴板内容
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, "Clipboard test")
    }
    
    func testReadClipboard_withPermission_shouldSucceed() {
        // 先设置剪贴板内容
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Test clipboard content", forType: .string)
        
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .clipboard)
        ])
        
        let result = context.evaluateScript("lightlauncher.readClipboard();")
        
        XCTAssertEqual(result?.toString(), "Test clipboard content")
    }
    
    // MARK: - 权限检查 API 测试
    
    func testHasFileWritePermission_shouldReturnCorrectValue() {
        // 无权限
        let (_, context1, _) = createTestSetup(permissions: [])
        let result1 = context1.evaluateScript("lightlauncher.hasFileWritePermission();")
        XCTAssertEqual(result1?.toBool(), false)
        
        // 有权限
        let (_, context2, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileWrite)
        ])
        let result2 = context2.evaluateScript("lightlauncher.hasFileWritePermission();")
        XCTAssertEqual(result2?.toBool(), true)
    }
    
    func testHasNetworkPermission_shouldReturnCorrectValue() {
        // 无权限
        let (_, context1, _) = createTestSetup(permissions: [])
        let result1 = context1.evaluateScript("lightlauncher.hasNetworkPermission();")
        XCTAssertEqual(result1?.toBool(), false)
        
        // 有权限
        let (_, context2, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .network)
        ])
        let result2 = context2.evaluateScript("lightlauncher.hasNetworkPermission();")
        XCTAssertEqual(result2?.toBool(), true)
    }
    
    func testHasClipboardPermission_shouldReturnCorrectValue() {
        // 无权限
        let (_, context1, _) = createTestSetup(permissions: [])
        let result1 = context1.evaluateScript("lightlauncher.hasClipboardPermission();")
        XCTAssertEqual(result1?.toBool(), false)
        
        // 有权限
        let (_, context2, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .clipboard)
        ])
        let result2 = context2.evaluateScript("lightlauncher.hasClipboardPermission();")
        XCTAssertEqual(result2?.toBool(), true)
    }
    
    // MARK: - 边界情况测试
    
    func testDisplayAPI_withInvalidData_shouldNotCrash() {
        let (_, context, _) = createTestSetup()
        
        // 传入无效数据不应崩溃
        context.evaluateScript("lightlauncher.display(null);")
        context.evaluateScript("lightlauncher.display(undefined);")
        context.evaluateScript("lightlauncher.display('string');")
        context.evaluateScript("lightlauncher.display(123);")
    }
    
    func testDisplayAPI_withPartialData_shouldHandleGracefully() {
        let (instance, context, _) = createTestSetup()
        
        // 只有 title 的项
        context.evaluateScript("""
        lightlauncher.display([
            { title: 'Title only' },
            { title: 'With subtitle', subtitle: 'Subtitle' }
        ]);
        """)
        
        let expectation = XCTestExpectation(description: "Items updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(instance.currentItems.count, 2)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testReadFile_withNonexistentFile_shouldReturnNil() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileRead)
        ])
        
        let result = context.evaluateScript("lightlauncher.readFile('/nonexistent/file.txt');")
        
        XCTAssertTrue(result?.isNull ?? false || result?.isUndefined ?? false)
    }
    
    func testWriteFile_withInvalidPath_shouldReturnFalse() {
        let (_, context, _) = createTestSetup(permissions: [
            PluginPermissionSpec(type: .fileWrite)
        ])
        
        // 无效路径
        let result = context.evaluateScript("""
        lightlauncher.writeFile({
            path: '',
            content: 'test'
        });
        """)
        
        XCTAssertEqual(result?.toBool(), false)
    }
    
    // MARK: - 辅助方法
    
    private func createTestSetup(
        permissions: [PluginPermissionSpec] = [],
        config: [String: Any] = [:]
    ) -> (PluginInstance, JSContext, Plugin) {
        let manifest = PluginManifest(
            name: "test_api_plugin",
            version: "1.0.0",
            displayName: "Test API Plugin",
            description: "Plugin for API testing",
            command: "testapi",
            author: "Test Author",
            main: "main.js",
            placeholder: nil,
            iconName: nil,
            shouldHideWindowAfterAction: nil,
            help: nil,
            interface: nil,
            permissions: permissions.isEmpty ? nil : permissions,
            minLightLauncherVersion: nil,
            maxLightLauncherVersion: nil,
            dependencies: nil,
            keywords: nil,
            homepage: nil,
            repository: nil
        )
        
        let plugin = Plugin(
            url: testPluginDirectory,
            manifest: manifest,
            script: "console.log('test');",
            effectiveConfig: config
        )
        
        let instance = PluginInstance(plugin: plugin)
        let context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print("JS Exception: \(exception?.toString() ?? "unknown")")
        }
        
        let apiManager = APIManager(pluginInstance: instance)
        apiManager.injectAPIs(into: context)
        
        instance.context = context
        instance.apiManager = apiManager
        
        return (instance, context, plugin)
    }
}
