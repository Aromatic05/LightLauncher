import XCTest
@testable import LightLauncher

@MainActor
final class TerminalModeTests: XCTestCase {
    private let controller = TerminalModeController.shared

    override func setUp() async throws {
        try await super.setUp()
        controller.cleanup()
    }

    override func tearDown() async throws {
        controller.cleanup()
        try await super.tearDown()
    }

    func testDefaultCopy_usesUnifiedChineseTerms() {
        XCTAssertEqual(controller.displayName, "终端执行")
        XCTAssertEqual(controller.placeholder, "输入要执行的终端命令...")
        XCTAssertEqual(controller.modeDescription, "在终端中执行命令")
    }

    func testHelpText_describesTriggerEnterAndExit() {
        XCTAssertEqual(
            controller.getHelpText(),
            [
                "在 > 后输入终端命令",
                "按 Enter 在终端中执行命令",
                "按 Esc 退出",
            ]
        )
    }

    func testHandleInputAndCleanup_manageCurrentCommand() {
        controller.handleInput(arguments: "swift test")

        XCTAssertEqual(controller.currentQuery, "swift test")
        XCTAssertEqual((controller.displayableItems.first as? TerminalHistoryItem)?.title, "swift test")

        controller.cleanup()

        XCTAssertEqual(controller.currentQuery, "")
    }
}
