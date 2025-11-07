import XCTest

@testable import LightLauncher

/// 测试 PluginLoader 的插件加载功能
@MainActor
final class PluginLoaderTests: XCTestCase {
    var loader: PluginLoader!
    var testPluginDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        loader = PluginLoader.shared

        // 创建临时测试插件目录
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_plugin_loader_\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: testPluginDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // 清理测试插件目录
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }

    // MARK: - 成功加载测试

    func testLoadPlugin_withValidManifestAndScript_shouldSucceed() throws {
        // 创建有效的 manifest.yaml
        let manifestContent = """
            name: test_plugin
            version: 1.0.0
            displayName: Test Plugin
            description: A test plugin
            command: /test
            author: Test Author
            main: main.js
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 创建有效的 main.js
        let scriptContent = """
            lightlauncher.registerCallback(function(input) {
                lightlauncher.display([
                    { title: "Test Result", subtitle: input }
                ]);
            });
            """
        let scriptURL = testPluginDirectory.appendingPathComponent("main.js")
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // 加载插件
        let plugin = try loader.load(from: testPluginDirectory)

        // 验证插件属性
        XCTAssertEqual(plugin.name, "test_plugin")
        XCTAssertEqual(plugin.version, "1.0.0")
        XCTAssertEqual(plugin.command, "/test")
        XCTAssertFalse(plugin.script.isEmpty)
    }

    func testLoadPlugin_withCustomMainFile_shouldSucceed() throws {
        // 创建指定自定义主文件的 manifest
        let manifestContent = """
            name: custom_main_plugin
            version: 1.0.0
            displayName: Custom Main Plugin
            description: Plugin with custom main file
            command: /custom
            main: custom.js
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 创建自定义主文件
        let scriptContent = "console.log('custom');"
        let scriptURL = testPluginDirectory.appendingPathComponent("custom.js")
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // 加载插件
        let plugin = try loader.load(from: testPluginDirectory)

        // 验证成功加载
        XCTAssertEqual(plugin.name, "custom_main_plugin")
        XCTAssertEqual(plugin.script, scriptContent)
    }

    func testLoadPlugin_withPermissions_shouldParseCorrectly() throws {
        // 创建带权限声明的 manifest
        let manifestContent = """
            name: permission_plugin
            version: 1.0.0
            displayName: Permission Plugin
            description: Plugin with permissions
            command: /perm
            permissions:
              - type: network
              - type: file_read
                directories:
                  - /Users/test/documents
              - type: clipboard
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 创建主文件
        let scriptURL = testPluginDirectory.appendingPathComponent("main.js")
        try "console.log('test');".write(to: scriptURL, atomically: true, encoding: .utf8)

        // 加载插件
        let plugin = try loader.load(from: testPluginDirectory)

        // 验证权限
        XCTAssertEqual(plugin.manifest.permissions?.count, 3)
        XCTAssertTrue(plugin.manifest.permissions?.contains { $0.type == .network } ?? false)
        XCTAssertTrue(plugin.manifest.permissions?.contains { $0.type == .fileRead } ?? false)
        XCTAssertTrue(plugin.manifest.permissions?.contains { $0.type == .clipboard } ?? false)

        // 验证文件权限的目录限制
        let fileReadPerm = plugin.manifest.permissions?.first { $0.type == .fileRead }
        XCTAssertNotNil(fileReadPerm?.directories)
        XCTAssertEqual(fileReadPerm?.directories?.first, "/Users/test/documents")
    }

    // MARK: - 失败情况测试

    func testLoadPlugin_withMissingManifest_shouldThrowError() {
        // 不创建任何文件，直接尝试加载
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory)) { error in
            if case PluginError.invalidManifest(let message) = error {
                XCTAssertTrue(message.contains("manifest.yaml"))
            } else {
                XCTFail("Expected invalidManifest error, got \(error)")
            }
        }
    }

    func testLoadPlugin_withMissingMainFile_shouldThrowError() throws {
        // 只创建 manifest，不创建主文件
        let manifestContent = """
            name: no_main_plugin
            version: 1.0.0
            displayName: No Main Plugin
            description: Plugin without main file
            command: /nomain
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 尝试加载应该失败
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory)) { error in
            if case PluginError.missingMainFile = error {
                // 正确的错误类型
            } else {
                XCTFail("Expected missingMainFile error, got \(error)")
            }
        }
    }

    func testLoadPlugin_withEmptyScript_shouldThrowError() throws {
        // 创建 manifest
        let manifestContent = """
            name: empty_script_plugin
            version: 1.0.0
            displayName: Empty Script Plugin
            description: Plugin with empty script
            command: /empty
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 创建空的主文件
        let scriptURL = testPluginDirectory.appendingPathComponent("main.js")
        try "   \n\n  ".write(to: scriptURL, atomically: true, encoding: .utf8)

        // 尝试加载应该失败
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory)) { error in
            if case PluginError.invalidScript(let message) = error {
                XCTAssertTrue(message.contains("空"))
            } else {
                XCTFail("Expected invalidScript error, got \(error)")
            }
        }
    }

    func testLoadPlugin_withInvalidManifestYAML_shouldThrowError() throws {
        // 创建无效的 YAML
        let manifestContent = """
            name: invalid_yaml
            version: 1.0.0
            displayName: [This is not valid
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 尝试加载应该失败
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory)) { error in
            if case PluginError.invalidManifest = error {
                // 正确的错误类型
            } else {
                XCTFail("Expected invalidManifest error, got \(error)")
            }
        }
    }

    func testLoadPlugin_withMissingRequiredFields_shouldThrowError() throws {
        // 创建缺少必需字段的 manifest
        let manifestContent = """
            name: missing_fields
            version: 1.0.0
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 尝试加载应该失败
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory))
    }

    func testLoadPlugin_withEmptyName_shouldThrowError() throws {
        // 创建空名称的 manifest
        let manifestContent = """
            name: ""
            version: 1.0.0
            displayName: Empty Name
            command: /empty
            """
        let manifestURL = testPluginDirectory.appendingPathComponent("manifest.yaml")
        try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)

        // 尝试加载应该失败
        XCTAssertThrowsError(try loader.load(from: testPluginDirectory)) { error in
            if case PluginError.invalidManifest(let message) = error {
                XCTAssertTrue(message.contains("名称"))
            } else {
                XCTFail("Expected invalidManifest error, got \(error)")
            }
        }
    }

    func testLoadPlugin_withNonexistentDirectory_shouldThrowError() {
        let nonexistentDir = URL(fileURLWithPath: "/nonexistent/directory/xyz")

        XCTAssertThrowsError(try loader.load(from: nonexistentDir)) { error in
            if case PluginError.loadFailed(let message) = error {
                XCTAssertTrue(message.contains("不存在"))
            } else {
                XCTFail("Expected loadFailed error, got \(error)")
            }
        }
    }

    // MARK: - 目录扫描测试

    func testScanPluginDirectories_shouldFindPluginFolders() throws {
        // 创建多个插件目录
        let plugin1Dir = testPluginDirectory.appendingPathComponent("plugin1")
        let plugin2Dir = testPluginDirectory.appendingPathComponent("plugin2")
        let notPluginDir = testPluginDirectory.appendingPathComponent("not_a_plugin")

        try FileManager.default.createDirectory(at: plugin1Dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plugin2Dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: notPluginDir, withIntermediateDirectories: true)

        // 只在 plugin1 和 plugin2 中创建 manifest
        try "name: plugin1\nversion: 1.0.0\ndisplayName: P1\ncommand: /p1".write(
            to: plugin1Dir.appendingPathComponent("manifest.yaml"),
            atomically: true,
            encoding: .utf8
        )
        try "name: plugin2\nversion: 1.0.0\ndisplayName: P2\ncommand: /p2".write(
            to: plugin2Dir.appendingPathComponent("manifest.yaml"),
            atomically: true,
            encoding: .utf8
        )

        // 扫描目录
        let foundDirs = loader.scanPluginDirectories(in: testPluginDirectory)

        // 验证找到了两个插件目录（以目录名判断以避免 URL 标准化差异）
        XCTAssertEqual(foundDirs.count, 2)
        let names = foundDirs.map { $0.lastPathComponent }
        XCTAssertTrue(names.contains(plugin1Dir.lastPathComponent))
        XCTAssertTrue(names.contains(plugin2Dir.lastPathComponent))
        XCTAssertFalse(foundDirs.contains(notPluginDir))
    }

    func testScanPluginDirectories_inNonexistentDirectory_shouldReturnEmpty() {
        let nonexistentDir = URL(fileURLWithPath: "/nonexistent/directory/xyz")
        let foundDirs = loader.scanPluginDirectories(in: nonexistentDir)

        XCTAssertTrue(foundDirs.isEmpty)
    }
}
