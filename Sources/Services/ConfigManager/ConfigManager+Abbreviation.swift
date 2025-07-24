import Foundation

extension ConfigManager {
    func addAbbreviation(key: String, values: [String]) {
        config.commonAbbreviations[key] = values
        saveConfig()
    }
    func removeAbbreviation(key: String) {
        config.commonAbbreviations.removeValue(forKey: key)
        saveConfig()
    }
}
