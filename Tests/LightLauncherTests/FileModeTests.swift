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
}
