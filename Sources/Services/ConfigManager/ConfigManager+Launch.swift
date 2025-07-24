import Foundation

extension ConfigManager {
    // MARK: - Abbreviations
    func addAbbreviation(key: String, values: [String]) {
        config.commonAbbreviations[key] = values
        saveConfig()
    }
    func removeAbbreviation(key: String) {
        config.commonAbbreviations.removeValue(forKey: key)
        saveConfig()
    }

    // MARK: - Search Directories
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
