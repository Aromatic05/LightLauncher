import XCTest
@testable import LightLauncher

@MainActor
final class FileModeTests: XCTestCase {
    let controller = FileModeController.shared

    override func setUp() async throws {
        try await super.setUp()
        // 确保初始状态可预测（在主线程调用隔离方法）
        await MainActor.run {
            controller.cleanup()
            LauncherViewModel.shared.clearSearch()
        }
    }

    func testNavigateToDirectory_updatesDisplayableItems_and_updatesLauncherQuery() {
        // 创建临时目录并添加文件
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let fileA = tmpDir.appendingPathComponent("fileA.txt")
        FileManager.default.createFile(atPath: fileA.path, contents: Data("hello".utf8))

        controller.navigateToDirectory(tmpDir)

        // displayableItems 应包含我们创建的文件
        let names = controller.displayableItems.compactMap { ($0 as? FileItem)?.name }
        XCTAssertTrue(names.contains("fileA.txt"))

        // LauncherViewModel 的查询应被更新为以 "/o " 开头
        XCTAssertTrue(LauncherViewModel.shared.searchText.hasPrefix("/o "))

        // 清理
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testHandleInput_filtersWithinCurrentDirectory() {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let fileA = tmpDir.appendingPathComponent("abc_file.txt")
        let fileB = tmpDir.appendingPathComponent("other.txt")
        FileManager.default.createFile(atPath: fileA.path, contents: Data("a".utf8))
        FileManager.default.createFile(atPath: fileB.path, contents: Data("b".utf8))

        controller.navigateToDirectory(tmpDir)

        // 在当前目录下搜索 "abc" 应只匹配第一个文件
        controller.handleInput(arguments: "abc")
        let names = controller.displayableItems.compactMap { ($0 as? FileItem)?.name }
        XCTAssertTrue(names.contains("abc_file.txt"))
        XCTAssertFalse(names.contains("other.txt"))

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testResetToStartScreen_setsStartPathsAndLauncherQuery() {
        controller.resetToStartScreen()
        // start paths 由 ConfigManager 提供，通常不为空
        let items = controller.displayableItems
        XCTAssertNotNil(items)
        XCTAssertTrue(LauncherViewModel.shared.searchText == "/o ")
    }

    func testNavigateThroughSymbolicLink_followsSymlinkAndUpdatesDisplayableItems() {
        // 创建目标目录并添加文件
        let targetDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let targetFile = targetDir.appendingPathComponent("linked.txt")
        FileManager.default.createFile(atPath: targetFile.path, contents: Data("linked".utf8))

        // 在临时目录创建一个符号链接指向 targetDir
        let symlink = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_link")
        // 使用 createSymbolicLink(at:withDestinationURL:)，忽略错误以防平台限制
        try? FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: targetDir)

        // 导航到符号链接路径 — 期望 FileMode 能解析并显示目标目录内容
        controller.navigateToDirectory(symlink)

        let names = controller.displayableItems.compactMap { ($0 as? FileItem)?.name }
        XCTAssertTrue(names.contains("linked.txt"), "Expected linked file from symlink target to be listed")

        // 清理
        try? FileManager.default.removeItem(at: symlink)
        try? FileManager.default.removeItem(at: targetDir)
    }

    func testBrokenSymbolicLink_isHandledGracefully_andReturnsNoItems() {
        // 创建一个指向不存在目标的符号链接
        let missingTarget = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_missing")
        let brokenLink = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_brokenlink")
        // 确保目标不存在
        try? FileManager.default.removeItem(at: missingTarget)
        // 创建符号链接指向不存在的位置
        try? FileManager.default.createSymbolicLink(at: brokenLink, withDestinationURL: missingTarget)

        // 导航到断开的符号链接，期望控制器不会崩溃并且不列出任何项
        controller.navigateToDirectory(brokenLink)

        let items = controller.displayableItems
        XCTAssertTrue(items.isEmpty, "Broken symlink should result in no displayable items")

        // 清理
        try? FileManager.default.removeItem(at: brokenLink)
    }
}
