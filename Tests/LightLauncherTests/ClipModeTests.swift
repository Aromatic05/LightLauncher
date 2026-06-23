import AppKit
import XCTest
@testable import LightLauncher

@MainActor
final class ClipModeTests: XCTestCase {
    private let controller = ClipModeController.shared
    private let hideWindowRecorder = HideWindowNotificationRecorder()

    override func setUp() async throws {
        try await super.setUp()
        controller.cleanup()
        controller.isSnippetMode = false
        hideWindowRecorder.reset()
    }

    override func tearDown() async throws {
        controller.cleanup()
        controller.isSnippetMode = false
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

    func testHandleShiftEnter_postsHideWindowNotification() {
        let handled = controller.handle(
            keyEvent: .enterWithModifiers(
                modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue))
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(hideWindowRecorder.requests, [true])
    }

    func testGetHelpText_describesOptionToggleAndDirectPaste() {
        let helpText = controller.getHelpText()

        XCTAssertEqual(
            helpText,
            [
                "浏览剪贴板历史",
                "按 Enter 将选中项目复制到剪贴板",
                "按 Shift+Enter 直接粘贴选中项目",
                "按 Option 在剪贴板历史和片段间切换",
                "输入关键词过滤历史，按 Esc 退出",
            ]
        )
    }

    func testSnippetMode_updatesDisplayNamePlaceholderAndDescription() {
        controller.isSnippetMode = true

        XCTAssertEqual(controller.displayName, "片段")
        XCTAssertEqual(controller.placeholder, "搜索片段...")
        XCTAssertEqual(controller.modeDescription, "浏览、复制或直接粘贴已保存的片段")
    }

    func testSnippetMode_helpText_matchesSnippetBehavior() {
        controller.isSnippetMode = true

        let helpText = controller.getHelpText()

        XCTAssertEqual(
            helpText,
            [
                "浏览并复制已保存的片段",
                "按 Enter 将选中片段复制到剪贴板",
                "按 Shift+Enter 直接粘贴选中片段",
                "按 Option 切回剪贴板历史",
                "输入关键词过滤片段，按 Esc 退出",
            ]
        )
    }

    func testClipboardMode_defaultDisplayNamePlaceholderAndDescription() {
        XCTAssertEqual(controller.displayName, "剪贴板历史")
        XCTAssertEqual(controller.commandDisplayName, "剪贴板历史")
        XCTAssertEqual(controller.placeholder, "搜索剪贴板历史...")
        XCTAssertEqual(controller.modeDescription, "浏览剪贴板历史，支持文本和文件")
    }

    func testCleanup_resetsSnippetModeAndClearsItems() {
        controller.isSnippetMode = true
        controller.displayableItems = [ClipboardItem.text("hello")]

        controller.cleanup()

        XCTAssertFalse(controller.isSnippetMode)
        XCTAssertTrue(controller.displayableItems.isEmpty)
    }
}
