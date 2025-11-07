import XCTest
@testable import LightLauncher

/// 测试 PluginPermissionManager 的权限管理功能
@MainActor
final class PluginPermissionManagerTests: XCTestCase {
    var permissionManager: PluginPermissionManager!
    var testPluginDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        permissionManager = PluginPermissionManager.shared
        
        testPluginDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_permissions_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testPluginDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testPluginDirectory)
        try await super.tearDown()
    }
    
    // MARK: - 基础权限检查测试
    
    func testHasPermission_withGrantedPermission_shouldReturnTrue() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .network),
            PluginPermissionSpec(type: .clipboard)
        ])
        
        XCTAssertTrue(permissionManager.hasPermission(plugin: plugin, type: .network))
        XCTAssertTrue(permissionManager.hasPermission(plugin: plugin, type: .clipboard))
    }
    
    func testHasPermission_withoutPermission_shouldReturnFalse() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .network)
        ])
        
        XCTAssertFalse(permissionManager.hasPermission(plugin: plugin, type: .fileRead))
        XCTAssertFalse(permissionManager.hasPermission(plugin: plugin, type: .clipboard))
    }
    
    func testHasPermission_withNoPermissions_shouldReturnFalse() {
        let plugin = createTestPlugin(permissions: nil)
        
        XCTAssertFalse(permissionManager.hasPermission(plugin: plugin, type: .network))
        XCTAssertFalse(permissionManager.hasPermission(plugin: plugin, type: .fileRead))
    }
    
    // MARK: - 文件权限测试
    
    func testHasFilePermission_withAllowedDirectory_shouldReturnTrue() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test/documents"])
        ])
        
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/test/documents/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withDisallowedDirectory_shouldReturnFalse() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test/documents"])
        ])
        
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/test/downloads/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withNoDirectoryRestrictions_shouldReturnTrue() {
        // 未指定目录限制时，应允许所有目录
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: nil)
        ])
        
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/any/path/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withEmptyDirectories_shouldReturnTrue() {
        // 空数组也应视为无限制
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: [])
        ])
        
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/any/path/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withMultipleDirectories_shouldCheckAll() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileWrite, directories: [
                "/Users/test/documents",
                "/Users/test/projects"
            ])
        ])
        
        // 应允许这两个目录
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileWrite,
                path: "/Users/test/documents/file.txt"
            )
        )
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileWrite,
                path: "/Users/test/projects/code.swift"
            )
        )
        
        // 不应允许其他目录
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileWrite,
                path: "/Users/test/downloads/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withNonFilePermissionType_shouldReturnFalse() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .network)
        ])
        
        // 非文件权限类型应返回 false
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .network,
                path: "/any/path"
            )
        )
    }
    
    func testHasFilePermission_separateReadWritePermissions_shouldWorkIndependently() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test/documents"]),
            PluginPermissionSpec(type: .fileWrite, directories: ["/Users/test/output"])
        ])
        
        // 读权限应只对 documents 有效
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/test/documents/file.txt"
            )
        )
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/test/output/file.txt"
            )
        )
        
        // 写权限应只对 output 有效
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileWrite,
                path: "/Users/test/output/file.txt"
            )
        )
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileWrite,
                path: "/Users/test/documents/file.txt"
            )
        )
    }
    
    // MARK: - 权限验证测试
    
    func testValidatePermissions_withValidPermissions_shouldReturnValid() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .network),
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test/documents"]),
            PluginPermissionSpec(type: .clipboard)
        ])
        
        let result = permissionManager.validatePermissions(for: plugin)
        
        if case .valid = result {
            // 成功
        } else {
            XCTFail("Expected valid result")
        }
    }
    
    func testValidatePermissions_withNoPermissions_shouldReturnValid() {
        let plugin = createTestPlugin(permissions: nil)
        
        let result = permissionManager.validatePermissions(for: plugin)
        
        if case .valid = result {
            // 成功
        } else {
            XCTFail("Expected valid result for plugin with no permissions")
        }
    }
    
    func testValidatePermissions_withEmptyPermissions_shouldReturnValid() {
        let plugin = createTestPlugin(permissions: [])
        
        let result = permissionManager.validatePermissions(for: plugin)
        
        if case .valid = result {
            // 成功
        } else {
            XCTFail("Expected valid result for plugin with empty permissions")
        }
    }
    
    // MARK: - 权限摘要测试
    
    func testGetPermissionSummary_shouldReturnCorrectInfo() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .network),
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test/documents"]),
            PluginPermissionSpec(type: .clipboard)
        ])
        
        let summary = permissionManager.getPermissionSummary(for: plugin)
        
        XCTAssertEqual(summary.permissions.count, 3)
        XCTAssertTrue(summary.permissions.contains { $0.type == .network })
        XCTAssertTrue(summary.permissions.contains { $0.type == .fileRead })
        XCTAssertTrue(summary.permissions.contains { $0.type == .clipboard })
        
        // 验证文件权限包含目录信息
        let fileReadPerm = summary.permissions.first { $0.type == .fileRead }
        XCTAssertNotNil(fileReadPerm?.directories)
        XCTAssertEqual(fileReadPerm?.directories?.first, "/Users/test/documents")
    }
    
    func testGetPermissionSummary_withNoPermissions_shouldReturnEmptyWithLowRisk() {
        let plugin = createTestPlugin(permissions: nil)
        
        let summary = permissionManager.getPermissionSummary(for: plugin)
        
        XCTAssertTrue(summary.permissions.isEmpty)
        XCTAssertEqual(summary.riskLevel, .low)
    }
    
    // MARK: - 边界情况测试
    
    func testHasFilePermission_withSubdirectory_shouldReturnTrue() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test"])
        ])
        
        // 应允许子目录
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/test/documents/subfolder/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withSimilarButDifferentPath_shouldReturnFalse() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/Users/test"])
        ])
        
        // 相似但不同的路径应被拒绝
        XCTAssertFalse(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/Users/testing/file.txt"
            )
        )
    }
    
    func testHasFilePermission_withRootPath_shouldBeCautious() {
        let plugin = createTestPlugin(permissions: [
            PluginPermissionSpec(type: .fileRead, directories: ["/"])
        ])
        
        // 根路径权限应能访问所有文件（虽然这在实践中应避免）
        XCTAssertTrue(
            permissionManager.hasFilePermission(
                plugin: plugin,
                type: .fileRead,
                path: "/any/path/file.txt"
            )
        )
    }
    
    // MARK: - 辅助方法
    
    private func createTestPlugin(permissions: [PluginPermissionSpec]?) -> Plugin {
        let manifest = PluginManifest(
            name: "test_plugin",
            version: "1.0.0",
            displayName: "Test Plugin",
            description: "Test plugin for permission testing",
            command: "test",
            author: "Test Author",
            main: "main.js",
            placeholder: nil,
            iconName: nil,
            shouldHideWindowAfterAction: nil,
            help: nil,
            interface: nil,
            permissions: permissions,
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
            script: "console.log('test');",
            effectiveConfig: [:]
        )
    }
}
