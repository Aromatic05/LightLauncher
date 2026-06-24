import AppKit
import Foundation
import SwiftUI

@MainActor
class AppScanner: ObservableObject {
    static let shared = AppScanner()

    @Published var applications: [AppInfo] = []

    private let configManager = ConfigManager.shared
    private let fileAccess = FileAccessService.shared
    private var isScanning = false

    var searchDirectories: [String] {
        configManager.config.searchDirectories.map { searchDirectory in
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
            applications = performScan()
            isScanning = false
        }

        Logger.shared.info("🔍 开始扫描应用程序...", owner: self)
    }

    private func performScan() -> [AppInfo] {
        scanApplications(in: searchDirectories)
    }

    func scanApplications(in directories: [String]) -> [AppInfo] {
        var foundApps = Set<AppInfo>()

        for directory in directories where fileAccess.directoryExists(atPath: directory) {
            let directoryURL = URL(fileURLWithPath: directory)
            let urls = fileAccess.enumeratedURLs(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            for fileURL in urls where fileURL.pathExtension == "app" {
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
        guard fileAccess.directoryExists(at: appURL) else { return nil }

        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let infoPlist = fileAccess.readPropertyList(from: infoPlistURL)
        let appName =
            (infoPlist?["CFBundleName"] as? String)
            ?? (infoPlist?["CFBundleDisplayName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        return AppInfo(name: appName, url: appURL)
    }
}
