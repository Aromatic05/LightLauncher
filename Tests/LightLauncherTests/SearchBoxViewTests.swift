import AppKit
import XCTest
@testable import LightLauncher

@MainActor
final class SearchBoxViewTests: XCTestCase {
    func testMoveCaretToEnd_collapsesSelectionAtEndOfEditorText() {
        let editor = NSTextView()
        editor.string = "/v "
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.count))

        let moved = SearchBoxView.moveCaretToEnd(in: editor)

        XCTAssertTrue(moved)
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 3, length: 0))
    }

    func testMoveCaretToEnd_collapsesSelectionAtEndOfCurrentEditorText() {
        let editor = NSTextView()
        editor.string = "clipboard"
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.count))

        let moved = SearchBoxView.moveCaretToEnd(in: editor)

        XCTAssertTrue(moved)
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 9, length: 0))
    }

    func testMoveCaretToEnd_ignoresNonTextResponder() {
        let responder = NSResponder()

        let moved = SearchBoxView.moveCaretToEnd(in: responder)

        XCTAssertFalse(moved)
    }

    func testHighRiskModePlaceholders_areLocalizedForSearchBox() {
        KillModeController.shared.cleanup()
        ClipModeController.shared.cleanup()
        TerminalModeController.shared.cleanup()
        PluginModeController.shared.cleanup()

        XCTAssertEqual(LauncherMode.kill.placeholder, "搜索运行中的应用...")
        XCTAssertEqual(LauncherMode.clip.placeholder, "搜索剪贴板历史...")
        XCTAssertEqual(LauncherMode.terminal.placeholder, "输入要执行的终端命令...")
        XCTAssertEqual(LauncherMode.plugin.placeholder, "输入插件命令...")
    }
}
