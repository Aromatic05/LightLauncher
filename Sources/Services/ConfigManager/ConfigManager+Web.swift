import Foundation

extension ConfigManager {
    func updateEnabledBrowsers(_ browsers: Set<BrowserType>) {
        config.modes.enabledBrowsers = browsers.map { $0.rawValue.lowercased() }
        saveConfig()
        BrowserDataManager.shared.setEnabledBrowsers(browsers)
    }
    func getEnabledBrowsers() -> Set<BrowserType> {
        let browserTypes = Set(
            config.modes.enabledBrowsers.compactMap { browserString in
                BrowserType.allCases.first {
                    $0.rawValue.lowercased() == browserString.lowercased()
                }
            })
        return browserTypes.isEmpty ? [.safari] : browserTypes
    }
}
