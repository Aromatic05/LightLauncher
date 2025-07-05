import Foundation
import AppKit

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
            let apps = await performScan()
            // 使用 Set 去重，然后转换为数组并排序
            let uniqueApps = Array(Set(apps))
            self.applications = uniqueApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.isScanning = false
        }
    }
    
    private func performScan() async -> [AppInfo] {
        var foundApps: [AppInfo] = []
        let fileManager = FileManager.default
        
        for directory in searchDirectories {
            guard fileManager.fileExists(atPath: directory) else { continue }
            
            let directoryURL = URL(fileURLWithPath: directory)
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            // Convert to async sequence to avoid async context issues
            let urls = Array(enumerator.compactMap { $0 as? URL })
            
            for fileURL in urls {
                // Check if this is an .app bundle
                guard fileURL.pathExtension == "app" else { continue }
                
                if let appInfo = await createAppInfo(from: fileURL) {
                    foundApps.append(appInfo)
                }
            }
        }
        
        return foundApps
    }
    
    private func createAppInfo(from appURL: URL) async -> AppInfo? {
        let fileManager = FileManager.default
        
        // Check if the app bundle exists and is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        
        // Try to get app name from Info.plist
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let appName: String
        
        if fileManager.fileExists(atPath: infoPlistURL.path),
           let infoPlist = NSDictionary(contentsOf: infoPlistURL),
           let bundleName = infoPlist["CFBundleName"] as? String {
            appName = bundleName
        } else if let bundleDisplayName = (NSDictionary(contentsOf: infoPlistURL)?["CFBundleDisplayName"] as? String) {
            appName = bundleDisplayName
        } else {
            // Fallback to filename without .app extension
            appName = appURL.deletingPathExtension().lastPathComponent
        }
        
        // Get app icon on main thread but create AppInfo synchronously
        return AppInfo(name: appName, url: appURL)
    }
}
