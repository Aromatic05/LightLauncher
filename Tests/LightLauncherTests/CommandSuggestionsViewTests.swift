import XCTest
@testable import LightLauncher

@MainActor
final class CommandSuggestionsViewTests: XCTestCase {
    func testSelectionHintText_matchesEnterKeyBehavior() {
        XCTAssertEqual(CommandSuggestionsView.selectionHintText, "Enter 选择 • ↑↓ 导航")
    }
}
