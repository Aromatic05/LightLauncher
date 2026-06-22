import XCTest
@testable import LightLauncher

@MainActor
final class ModePrefixConsistencyTests: XCTestCase {
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
            "Type after > to enter a shell command"
        )
    }
}
