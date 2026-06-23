import AppKit
import XCTest
@testable import LightLauncher

@MainActor
final class ClipModeTests: XCTestCase {
    private let controller = ClipModeController.shared
    private let windowRouterSpy = WindowRouterSpy()

    override func setUp() async throws {
        try await super.setUp()
        controller.cleanup()
        controller.isSnippetMode = false
        controller.windowRouter = windowRouterSpy
    }

    override func tearDown() async throws {
        controller.cleanup()
        controller.isSnippetMode = false
        controller.windowRouter = NotificationCenterWindowRouter()
        try await super.tearDown()
    }

    func testSimulateTextInput_restoresPreviousStringClipboardContents() {
        let pasteboard = NSPasteboard(name: .init("clipmode-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("original value", forType: .string)

        ClipModeController.simulateTextInput(
            "temporary value",
            pasteboard: pasteboard,
            restoreScheduler: { action in action() },
            eventPoster: { _, _, _, _ in }
        )

        XCTAssertEqual(pasteboard.string(forType: .string), "original value")
    }

    func testSimulateTextInput_restoresPreviousFileClipboardContents() {
        let pasteboard = NSPasteboard(name: .init("clipmode-test-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("clipmode-file-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data("file".utf8))
        defer { try? FileManager.default.removeItem(at: tempURL) }

        pasteboard.writeObjects([tempURL as NSURL])

        ClipModeController.simulateTextInput(
            "temporary value",
            pasteboard: pasteboard,
            restoreScheduler: { action in action() },
            eventPoster: { _, _, _, _ in }
        )

        let restoredURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertEqual(restoredURLs?.first, tempURL)
    }

    func testSimulateTextInput_withEmptyClipboard_restoresToEmptyState() {
        let pasteboard = NSPasteboard(name: .init("clipmode-test-\(UUID().uuidString)"))
        pasteboard.clearContents()

        ClipModeController.simulateTextInput(
            "temporary value",
            pasteboard: pasteboard,
            restoreScheduler: { action in action() },
            eventPoster: { _, _, _, _ in }
        )

        XCTAssertNil(pasteboard.string(forType: .string))
        let restoredURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertTrue(restoredURLs?.isEmpty ?? true)
    }

    func testHandleOptionFlagChanged_togglesSnippetMode() {
        XCTAssertFalse(controller.isSnippetMode)

        let handled = controller.handle(keyEvent: .optionFlagChanged(isPressed: true))

        XCTAssertTrue(handled)
        XCTAssertTrue(controller.isSnippetMode)
    }

    func testHandleCommandFlagChanged_doesNotToggleSnippetMode() {
        XCTAssertFalse(controller.isSnippetMode)

        let handled = controller.handle(keyEvent: .commandFlagChanged(isPressed: true))

        XCTAssertFalse(handled)
        XCTAssertFalse(controller.isSnippetMode)
    }

    func testHandleShiftEnter_requestsWindowHideThroughRouter() {
        let handled = controller.handle(
            keyEvent: .enterWithModifiers(
                modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue))
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(windowRouterSpy.hideRequests, [true])
    }

    func testGetHelpText_describesOptionToggleAndDirectPaste() {
        let helpText = controller.getHelpText()

        XCTAssertTrue(helpText.contains("Press Shift+Enter to paste directly"))
        XCTAssertTrue(
            helpText.contains("Press Option to switch between clipboard history and snippets")
        )
    }

    func testSnippetMode_updatesDisplayNamePlaceholderAndDescription() {
        controller.isSnippetMode = true

        XCTAssertEqual(controller.displayName, "Snippets")
        XCTAssertEqual(controller.placeholder, "Search snippets...")
        XCTAssertEqual(controller.modeDescription, "Browse, copy, and paste your saved snippets")
    }

    func testSnippetMode_helpText_matchesSnippetBehavior() {
        controller.isSnippetMode = true

        let helpText = controller.getHelpText()

        XCTAssertTrue(helpText.contains("Browse and copy saved snippets"))
        XCTAssertTrue(helpText.contains("Press Enter to copy the selected snippet"))
        XCTAssertTrue(helpText.contains("Press Shift+Enter to paste the selected snippet directly"))
        XCTAssertTrue(helpText.contains("Press Option to switch back to clipboard history"))
    }

    func testClipboardMode_defaultDisplayNamePlaceholderAndDescription() {
        XCTAssertEqual(controller.displayName, "Clipboard History")
        XCTAssertEqual(controller.placeholder, "Search clipboard history...")
        XCTAssertEqual(controller.modeDescription, "Browse and paste clipboard history (text/files)")
    }

    func testCleanup_resetsSnippetModeAndClearsItems() {
        controller.isSnippetMode = true
        controller.displayableItems = [ClipboardItem.text("hello")]

        controller.cleanup()

        XCTAssertFalse(controller.isSnippetMode)
        XCTAssertTrue(controller.displayableItems.isEmpty)
    }
}

@MainActor
private final class WindowRouterSpy: LauncherWindowRouting {
    var hideRequests: [Bool] = []

    func hideMainWindow(shouldActivatePreviousApp: Bool) {
        hideRequests.append(shouldActivatePreviousApp)
    }
}
