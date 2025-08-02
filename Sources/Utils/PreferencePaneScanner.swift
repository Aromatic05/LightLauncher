import Foundation
import AppKit
import SwiftUI

@MainActor
class PreferencePaneScanner: ObservableObject {
    static let shared = PreferencePaneScanner()
    @Published var panes: [PreferencePaneItem] = []
    private var isScanning = false

    var searchDirectories: [String] {
        [
            "/System/Library/PreferencePanes",
            "/Library/PreferencePanes",
            NSString(string: "~/Library/PreferencePanes").expandingTildeInPath
        ]
    }

    func scanForPreferencePanes() {
        guard !isScanning else { return }
        isScanning = true

        Task {
            let foundPanes = await performScan()
            let uniquePanes = Array(Set(foundPanes))
            self.panes = uniquePanes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            self.isScanning = false
        }
    }

    private func performScan() async -> [PreferencePaneItem] {
        var foundPanes: [PreferencePaneItem] = []
        let fileManager = FileManager.default

        for directory in searchDirectories {
            guard fileManager.fileExists(atPath: directory) else { continue }
            let directoryURL = URL(fileURLWithPath: directory)
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            let urls = Array(enumerator.compactMap { $0 as? URL })
            for fileURL in urls {
                guard fileURL.pathExtension == "prefPane" else { continue }
                if let paneItem = await createPaneItem(from: fileURL) {
                    foundPanes.append(paneItem)
                }
            }
        }
        return foundPanes
    }

    private func createPaneItem(from paneURL: URL) async -> PreferencePaneItem? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: paneURL.path, isDirectory: &isDirectory)
        if !exists {
            return nil
        }
        // 某些 prefPane 可能不是目录，尝试继续处理
        let paneName: String = paneURL.deletingPathExtension().lastPathComponent
        let paneSubtitle: String? = nil
        let paneIcon: NSImage? = NSWorkspace.shared.icon(forFile: paneURL.path)
        return PreferencePaneItem(title: paneName, subtitle: paneSubtitle, icon: paneIcon, url: paneURL)
    }
}
