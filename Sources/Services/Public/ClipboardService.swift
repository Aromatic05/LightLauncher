import AppKit
import Foundation

@MainActor
final class ClipboardService {
    static let shared = ClipboardService()

    private let pasteboard = NSPasteboard.general

    private init() {}

    func copy(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
