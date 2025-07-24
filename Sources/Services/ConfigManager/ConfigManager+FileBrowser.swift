import Foundation

extension ConfigManager {
    func getFileBrowserStartPaths() -> [String] {
        return config.modes.fileBrowserStartPaths.filter { path in
            FileManager.default.fileExists(atPath: path)
        }
    }
    func addFileBrowserStartPath(_ path: String) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return }
        if !config.modes.fileBrowserStartPaths.contains(path) {
            config.modes.fileBrowserStartPaths.append(path)
            saveConfig()
        }
    }
    func removeFileBrowserStartPath(_ path: String) {
        config.modes.fileBrowserStartPaths.removeAll { $0 == path }
        saveConfig()
    }
    func updateFileBrowserStartPaths(_ paths: [String]) {
        let validPaths = paths.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        config.modes.fileBrowserStartPaths = validPaths
        saveConfig()
    }
}
