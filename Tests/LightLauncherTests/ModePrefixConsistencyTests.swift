import XCTest
@testable import LightLauncher

@MainActor
final class ModePrefixConsistencyTests: XCTestCase {
    func testCommandReference_returnsControllerPrefix() {
        XCTAssertEqual(KillModeController.shared.commandReference(), "/k")
        XCTAssertEqual(SearchModeController.shared.commandReference(), "/s")
    }

    func testCommandReference_canIncludeTrailingSpace() {
        XCTAssertEqual(SearchModeController.shared.commandReference(includeTrailingSpace: true), "/s ")
    }

    func testClipModeSettingsTitle_usesActualPrefix() {
        XCTAssertEqual(
            ClipModeController.shared.settingsTitle("剪贴板模式"),
            "剪贴板模式 (/v)"
        )
    }

    func testTerminalModeSettingsTitle_usesActualPrefix() {
        XCTAssertEqual(
            TerminalModeController.shared.settingsTitle("终端执行"),
            "终端执行 (>)"
        )
    }

    func testTerminalHelpText_usesActualPrefix() {
        XCTAssertEqual(
            TerminalModeController.shared.getHelpText().first,
            "在 > 后输入终端命令"
        )
    }

    func testSearchHelpText_usesActualPrefix() {
        XCTAssertEqual(
            SearchModeController.shared.getHelpText().first,
            "Type after /s to search the web"
        )
    }
}
