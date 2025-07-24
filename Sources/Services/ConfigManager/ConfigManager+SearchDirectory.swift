import Foundation

extension ConfigManager {
    func addSearchDirectory(_ path: String) {
        if !config.searchDirectories.contains(where: { $0.path == path }) {
            let newDirectory = SearchDirectory(path: path)
            config.searchDirectories.append(newDirectory)
            saveConfig()
        }
    }
    func removeSearchDirectory(_ path: String) {
        config.searchDirectories.removeAll { $0.path == path }
        saveConfig()
    }
    func removeSearchDirectory(_ directory: SearchDirectory) {
        config.searchDirectories.removeAll { $0.path == directory.path }
        saveConfig()
    }
}
