import AppKit
import Combine
import SwiftUI
import XCTest
@testable import LightLauncher

@MainActor
final class KillModeTests: XCTestCase {
    private let controller = KillModeController.shared

    override func setUp() async throws {
        try await super.setUp()
        controller.cleanup()
        controller.forceKillEnabled = false
    }

    override func tearDown() async throws {
        controller.cleanup()
        controller.forceKillEnabled = false
        try await super.tearDown()
    }

    func testSelectKillAppByNumber_withOutOfBoundsIndex_returnsFalse() {
        controller.displayableItems = [TestKillItem(title: "Only Item", executeResult: true)]

        XCTAssertFalse(controller.selectKillAppByNumber(2))
    }

    func testHandleNumericKey_withOutOfBoundsIndex_doesNotPostHideNotification() {
        controller.displayableItems = [TestKillItem(title: "Only Item", executeResult: true)]

        let hideExpectation = expectation(forNotification: .hideWindow, object: nil)
        hideExpectation.isInverted = true
        let observer = NotificationCenter.default.addObserver(
            forName: .hideWindow,
            object: nil,
            queue: nil
        ) { _ in
            hideExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let handled = controller.handle(keyEvent: .numeric(2))

        XCTAssertTrue(handled)
        wait(for: [hideExpectation], timeout: 0.1)
    }

    func testHandleNumericKey_withValidIndex_executesActionAndPostsHideNotification() {
        let item = TestKillItem(title: "Kill Me", executeResult: true)
        controller.displayableItems = [item]

        let hideExpectation = expectation(forNotification: .hideWindow, object: nil)
        let observer = NotificationCenter.default.addObserver(
            forName: .hideWindow,
            object: nil,
            queue: nil
        ) { _ in
            hideExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let handled = controller.handle(keyEvent: .numeric(1))

        XCTAssertTrue(handled)
        XCTAssertEqual(item.executionCount, 1)
        wait(for: [hideExpectation], timeout: 0.1)
    }

    func testHandleOptionFlagChanged_togglesForceKillMode() {
        XCTAssertFalse(controller.forceKillEnabled)

        let handled = controller.handle(keyEvent: .optionFlagChanged(isPressed: true))

        XCTAssertTrue(handled)
        XCTAssertTrue(controller.forceKillEnabled)
    }

    func testHandleCommandFlagChanged_doesNotToggleForceKillMode() {
        XCTAssertFalse(controller.forceKillEnabled)

        let handled = controller.handle(keyEvent: .commandFlagChanged(isPressed: true))

        XCTAssertFalse(handled)
        XCTAssertFalse(controller.forceKillEnabled)
    }

    func testGetHelpText_describesOptionToggle() {
        XCTAssertTrue(controller.getHelpText().contains("Press Option to toggle force kill"))
    }

    func testCleanup_resetsForceKillMode() {
        controller.forceKillEnabled = true
        controller.displayableItems = [TestKillItem(title: "Kill Me", executeResult: true)]

        controller.cleanup()

        XCTAssertFalse(controller.forceKillEnabled)
        XCTAssertTrue(controller.displayableItems.isEmpty)
    }

    func testForceKillToggle_publishesDataDidChange() async {
        let expectation = XCTestExpectation(description: "force kill change published")
        let cancellable = controller.dataDidChange.sink {
            expectation.fulfill()
        }
        defer { cancellable.cancel() }

        controller.forceKillEnabled = true

        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

private final class TestKillItem: DisplayableItem {
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

    static func == (lhs: TestKillItem, rhs: TestKillItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
