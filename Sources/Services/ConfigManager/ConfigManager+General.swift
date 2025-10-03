import Foundation

extension ConfigManager {
    // MARK: Modes
    func updateModeSettings() {
        let settingsManager = SettingsManager.shared
        for (key, value) in settingsManager.modeEnabled {
            switch key {
            case "kill": config.modes.enabled["kill"] = value
            case "search": config.modes.enabled["search"] = value
            case "web": config.modes.enabled["web"] = value
            case "terminal": config.modes.enabled["terminal"] = value
            case "file": config.modes.enabled["file"] = value
            case "clip": config.modes.enabled["clip"] = true
            case "plugin": config.modes.enabled["plugin"] = true
            case "launch": config.modes.enabled["launch"] = true
            default: break
            }
        }
        config.modes.showCommandSuggestions = settingsManager.showCommandSuggestions
        saveConfig()
    }
    func loadModeSettings() {
        let settingsManager = SettingsManager.shared
        settingsManager.modeEnabled["kill"] = config.modes.enabled["kill"] ?? true
        settingsManager.modeEnabled["search"] = config.modes.enabled["search"] ?? true
        settingsManager.modeEnabled["web"] = config.modes.enabled["web"] ?? true
        settingsManager.modeEnabled["terminal"] = config.modes.enabled["terminal"] ?? true
        settingsManager.modeEnabled["file"] = config.modes.enabled["file"] ?? true
        settingsManager.modeEnabled["clip"] = config.modes.enabled["clip"] ?? true
        settingsManager.modeEnabled["plugin"] = config.modes.enabled["plugin"] ?? true
        settingsManager.modeEnabled["launch"] = config.modes.enabled["launch"] ?? true
        settingsManager.showCommandSuggestions = config.modes.showCommandSuggestions
    }

    // MARK: HotKey
    func updateHotKey(modifiers: UInt32, keyCode: UInt32) {
        // 更新 config
        config.hotKey.modifiers = modifiers
        config.hotKey.keyCode = keyCode
        saveConfig()
        
        // 同步更新 SettingsManager（它会发送通知）
        SettingsManager.shared.updateHotKey(modifiers: modifiers, keyCode: keyCode)
    }
}
