import AppKit
import XCTest
@testable import LightLauncher

@MainActor
final class ClipModeTests: XCTestCase {
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
}
