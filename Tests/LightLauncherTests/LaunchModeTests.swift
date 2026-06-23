import AppKit
import SwiftUI
import XCTest
@testable import LightLauncher

@MainActor
final class LaunchModeTests: XCTestCase {
    private let controller = LaunchModeController.shared
    private let hideWindowRecorder = HideWindowNotificationRecorder()

    override func setUp() async throws {
        try await super.setUp()
        controller.cleanup()
        hideWindowRecorder.reset()
    }

    override func tearDown() async throws {
        controller.cleanup()
        try await super.tearDown()
    }

    func testHandleNumericKey_withOutOfBoundsIndex_doesNotRequestWindowHide() {
        controller.displayableItems = [TestLaunchItem(title: "Only Item", executeResult: true)]

        let handled = controller.handle(keyEvent: .numeric(2))

        XCTAssertTrue(handled)
        XCTAssertTrue(hideWindowRecorder.requests.isEmpty)
    }

    func testHandleNumericKey_withValidIndex_executesActionAndPostsHideWindowNotification() {
        let item = TestLaunchItem(title: "Launch Me", executeResult: true)
        controller.displayableItems = [item]

        let handled = controller.handle(keyEvent: .numeric(1))

        XCTAssertTrue(handled)
        XCTAssertEqual(item.executionCount, 1)
        XCTAssertEqual(hideWindowRecorder.requests, [true])
    }
}

private final class TestLaunchItem: DisplayableItem {
    let id = UUID()
    let title: String
    let executeResult: Bool
    private(set) var executionCount = 0

    init(title: String, executeResult: Bool) {
        self.title = title
        self.executeResult = executeResult
    }

    var subtitle: String? { nil }
    var icon: NSImage? { nil }

    @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(EmptyView())
    }

    @MainActor
    func executeAction() -> Bool {
        executionCount += 1
        return executeResult
    }

    static func == (lhs: TestLaunchItem, rhs: TestLaunchItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
