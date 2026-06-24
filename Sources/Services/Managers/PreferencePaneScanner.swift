import AppKit
import Foundation
import SwiftUI

@MainActor
class PreferencePaneScanner: ObservableObject {
    static let shared = PreferencePaneScanner()

    @Published var panes: [PreferencePaneItem] = []

    private let fileAccess = FileAccessService.shared
    private var isScanning = false

    var searchDirectories: [String] {
        [
            "/System/Library/PreferencePanes",
            "/Library/PreferencePanes",
            NSString(string: "~/Library/PreferencePanes").expandingTildeInPath,
        ]
    }

    func scanForPreferencePanes() {
        guard !isScanning else { return }
        isScanning = true

        Task {
            let foundPanes = await performScan()
            let uniquePanes = Array(Set(foundPanes))
            panes = uniquePanes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            isScanning = false
        }
    }

    private func performScan() async -> [PreferencePaneItem] {
        var foundPanes: [PreferencePaneItem] = []

        for directory in searchDirectories where fileAccess.directoryExists(atPath: directory) {
            let directoryURL = URL(fileURLWithPath: directory)
            let urls = fileAccess.enumeratedURLs(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            for fileURL in urls where fileURL.pathExtension == "prefPane" {
                if let paneItem = await createPaneItem(from: fileURL) {
                    foundPanes.append(paneItem)
                }
            }
        }

        return foundPanes
    }

    private func createPaneItem(from paneURL: URL) async -> PreferencePaneItem? {
        guard fileAccess.fileExists(at: paneURL) else { return nil }

        let paneName = paneURL.deletingPathExtension().lastPathComponent
        let paneSubtitle: String? = nil
        let paneIcon = NSWorkspace.shared.icon(forFile: paneURL.path)
        return PreferencePaneItem(
            title: paneName,
            subtitle: paneSubtitle,
            icon: paneIcon,
            url: paneURL
        )
    }
}
