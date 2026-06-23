import AppKit
import Foundation
import SwiftUI

@MainActor
class AppScanner: ObservableObject {
    static let shared = AppScanner()
    @Published var applications: [AppInfo] = []
    private var isScanning = false
    private let configManager = ConfigManager.shared

    var searchDirectories: [String] {
        return configManager.config.searchDirectories.map { searchDirectory in
            let path = searchDirectory.path
            if path.hasPrefix("~/") {
                return NSString(string: path).expandingTildeInPath
            }
            return path
        }
    }

    func scanForApplications() {
        guard !isScanning else { return }
        isScanning = true

        Task {
            self.applications = performScan()
            self.isScanning = false
        }

        Logger.shared.info("🔍 开始扫描应用程序...", owner: self)
    }

    private func performScan() -> [AppInfo] {
        scanApplications(in: searchDirectories)
    }

    func scanApplications(in directories: [String]) -> [AppInfo] {
        var foundApps = Set<AppInfo>()
        let fileManager = FileManager.default

        for directory in directories {
            guard fileManager.fileExists(atPath: directory) else { continue }

            let directoryURL = URL(fileURLWithPath: directory)
            guard
                let enumerator = fileManager.enumerator(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
            else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }

                if let appInfo = createAppInfo(from: fileURL) {
                    foundApps.insert(appInfo)
                }
            }
        }

        return foundApps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func createAppInfo(from appURL: URL) -> AppInfo? {
        let fileManager = FileManager.default

        // Check if the app bundle exists and is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return nil
        }

        // Try to get app name from Info.plist
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let appName: String

        if fileManager.fileExists(atPath: infoPlistURL.path),
            let infoPlist = NSDictionary(contentsOf: infoPlistURL),
            let bundleName = infoPlist["CFBundleName"] as? String
        {
            appName = bundleName
        } else if let bundleDisplayName =
            (NSDictionary(contentsOf: infoPlistURL)?["CFBundleDisplayName"] as? String)
        {
            appName = bundleDisplayName
        } else {
            // Fallback to filename without .app extension
            appName = appURL.deletingPathExtension().lastPathComponent
        }

        // Get app icon on main thread but create AppInfo synchronously
        return AppInfo(name: appName, url: appURL)
    }
}
