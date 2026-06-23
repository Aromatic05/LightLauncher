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
}
