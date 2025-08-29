import Carbon
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
        config.hotKey.modifiers = modifiers
        config.hotKey.keyCode = keyCode
        saveConfig()
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }

    func getHotKeyDescription() -> String {
        let modifiers = config.hotKey.modifiers
        let keyCode = config.hotKey.keyCode
        var description = ""
        if modifiers == 0x100010 {
            description += "R⌘"
        } else if modifiers == 0x100040 {
            description += "R⌥"
        } else {
            if modifiers & UInt32(cmdKey) != 0 { description += "⌘" }
            if modifiers & UInt32(optionKey) != 0 { description += "⌥" }
            if modifiers & UInt32(controlKey) != 0 { description += "⌃" }
            if modifiers & UInt32(shiftKey) != 0 { description += "⇧" }
        }
        if keyCode == 0 { return description.isEmpty ? "无" : description }
        description += ConfigManager.getKeyName(for: keyCode)
        return description
    }

    static func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        default: return "Key(\(keyCode))"
        }
    }
}
