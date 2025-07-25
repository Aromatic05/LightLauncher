import Foundation
import AppKit
import SwiftUI

struct PreferencePaneItem: DisplayableItem {
    let id: UUID = UUID()
    let title: String
    let subtitle: String?
    let icon: NSImage?
    let url: URL

    // 只用名称和路径做哈希
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(url)
    }
    static func == (lhs: PreferencePaneItem, rhs: PreferencePaneItem) -> Bool {
        lhs.title == rhs.title && lhs.url == rhs.url
    }

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(
            HStack {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                }
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        )
    }
}

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
        guard fileManager.fileExists(atPath: paneURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        let infoPlistURL = paneURL.appendingPathComponent("Contents/Info.plist")
        var paneName: String = paneURL.deletingPathExtension().lastPathComponent
        var paneSubtitle: String? = nil
        var paneIcon: NSImage? = nil
        if fileManager.fileExists(atPath: infoPlistURL.path),
           let infoPlist = NSDictionary(contentsOf: infoPlistURL) {
            if let bundleName = infoPlist["CFBundleName"] as? String {
                paneName = bundleName
            } else if let bundleDisplayName = infoPlist["CFBundleDisplayName"] as? String {
                paneName = bundleDisplayName
            }
            if let bundleIdentifier = infoPlist["CFBundleIdentifier"] as? String {
                paneSubtitle = bundleIdentifier
            }
            if let iconFile = infoPlist["CFBundleIconFile"] as? String {
                let iconURL = paneURL.appendingPathComponent("Contents/Resources/")
                    .appendingPathComponent(iconFile)
                if let image = NSImage(contentsOf: iconURL) {
                    paneIcon = image
                }
            }
        }
        return PreferencePaneItem(title: paneName, subtitle: paneSubtitle, icon: paneIcon, url: paneURL)
    }
}
