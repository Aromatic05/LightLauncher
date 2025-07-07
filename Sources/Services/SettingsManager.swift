import Foundation
import ServiceManagement
import Carbon

// 设置管理器
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var isAutoStartEnabled: Bool = false
    @Published var hotKeyModifiers: UInt32 = UInt32(optionKey)
    @Published var hotKeyCode: UInt32 = UInt32(kVK_Space)
    
    // 模式开关（用字典统一管理）
    @Published var modeEnabled: [String: Bool] = [
        "kill": true,
        "search": true,
        "web": true,
        "terminal": true,
        "file": true,
        "clip": true,
        "plugin": true,
        "launch": true
    ]
    @Published var showCommandSuggestions: Bool = true
    
    private let userDefaults = UserDefaults.standard
    
    // 设置键
    private enum Keys {
        static let autoStart = "autoStart"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyCode = "hotKeyCode"
        static let modeEnabled = "modeEnabled"
        static let showCommandSuggestions = "showCommandSuggestions"
    }
    
    private init() {
        loadSettings()
    }
    
    // MARK: - 加载和保存设置
    
    private func loadSettings() {
        isAutoStartEnabled = userDefaults.bool(forKey: Keys.autoStart)
        hotKeyModifiers = UInt32(userDefaults.integer(forKey: Keys.hotKeyModifiers))
        hotKeyCode = UInt32(userDefaults.integer(forKey: Keys.hotKeyCode))
        // 加载模式设置，默认启用
        if let dict = userDefaults.dictionary(forKey: Keys.modeEnabled) as? [String: Bool] {
            modeEnabled.merge(dict) { _, new in new }
        }
        showCommandSuggestions = userDefaults.object(forKey: Keys.showCommandSuggestions) as? Bool ?? true
        if hotKeyModifiers == 0 {
            hotKeyModifiers = UInt32(optionKey)
            hotKeyCode = UInt32(kVK_Space)
        }
    }
    
    private func saveSettings() {
        userDefaults.set(isAutoStartEnabled, forKey: Keys.autoStart)
        userDefaults.set(Int(hotKeyModifiers), forKey: Keys.hotKeyModifiers)
        userDefaults.set(Int(hotKeyCode), forKey: Keys.hotKeyCode)
        userDefaults.set(modeEnabled, forKey: Keys.modeEnabled)
        userDefaults.set(showCommandSuggestions, forKey: Keys.showCommandSuggestions)
    }
    
    // MARK: - 开机自启动
    
    func toggleAutoStart() {
        isAutoStartEnabled.toggle()
        setAutoStart(enabled: isAutoStartEnabled)
        saveSettings()
    }
    
    private func setAutoStart(enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.lightlauncher.app"
        
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新的 API
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        } else {
            // macOS 12 及以下使用旧的 API
            if enabled {
                SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            } else {
                SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
            }
        }
    }
    
    // 检查是否已启用开机自启动
    func checkAutoStartStatus() {
        if #available(macOS 13.0, *) {
            isAutoStartEnabled = SMAppService.mainApp.status == .enabled
        } else {
            // 对于旧版本，我们依赖 UserDefaults 的值
            isAutoStartEnabled = userDefaults.bool(forKey: Keys.autoStart)
        }
    }
    
    // MARK: - 热键设置
    
    // MARK: - 模式设置
    func toggleMode(_ key: String) {
        modeEnabled[key]?.toggle()
        saveSettings()
        Task { @MainActor in
            ConfigManager.shared.updateModeSettings()
        }
    }
    func isModeEnabled(_ key: String) -> Bool {
        modeEnabled[key] ?? true
    }
    
    // MARK: - 热键设置
    
    func updateHotKey(modifiers: UInt32, keyCode: UInt32) {
        hotKeyModifiers = modifiers
        hotKeyCode = keyCode
        saveSettings()
        
        // 通知 AppDelegate 更新热键
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
    
    // 获取热键描述
    func getHotKeyDescription() -> String {
        var description = ""
        
        // 检查特殊的左右修饰键
        if hotKeyModifiers == 0x100010 { // 右 Command
            description += "R⌘"
        } else if hotKeyModifiers == 0x100040 { // 右 Option
            description += "R⌥"
        } else {
            // 标准修饰键
            if hotKeyModifiers & UInt32(cmdKey) != 0 {
                description += "⌘"
            }
            if hotKeyModifiers & UInt32(optionKey) != 0 {
                description += "⌥"
            }
            if hotKeyModifiers & UInt32(controlKey) != 0 {
                description += "⌃"
            }
            if hotKeyModifiers & UInt32(shiftKey) != 0 {
                description += "⇧"
            }
        }
        
        // 如果只有修饰键没有普通键，则不添加键名
        if hotKeyCode == 0 {
            return description.isEmpty ? "无" : description
        }
        
        description += getKeyName(for: hotKeyCode)
        
        return description
    }
    
    private func getKeyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space):
            return "Space"
        case UInt32(kVK_Return):
            return "Return"
        case UInt32(kVK_Escape):
            return "Escape"
        case UInt32(kVK_Tab):
            return "Tab"
        case UInt32(kVK_Delete):
            return "Delete"
        case UInt32(kVK_F1):
            return "F1"
        case UInt32(kVK_F2):
            return "F2"
        case UInt32(kVK_F3):
            return "F3"
        case UInt32(kVK_F4):
            return "F4"
        case UInt32(kVK_F5):
            return "F5"
        case UInt32(kVK_F6):
            return "F6"
        case UInt32(kVK_F7):
            return "F7"
        case UInt32(kVK_F8):
            return "F8"
        case UInt32(kVK_F9):
            return "F9"
        case UInt32(kVK_F10):
            return "F10"
        case UInt32(kVK_F11):
            return "F11"
        case UInt32(kVK_F12):
            return "F12"
        case UInt32(kVK_ANSI_A):
            return "A"
        case UInt32(kVK_ANSI_B):
            return "B"
        case UInt32(kVK_ANSI_C):
            return "C"
        case UInt32(kVK_ANSI_D):
            return "D"
        case UInt32(kVK_ANSI_E):
            return "E"
        case UInt32(kVK_ANSI_F):
            return "F"
        case UInt32(kVK_ANSI_G):
            return "G"
        case UInt32(kVK_ANSI_H):
            return "H"
        case UInt32(kVK_ANSI_I):
            return "I"
        case UInt32(kVK_ANSI_J):
            return "J"
        case UInt32(kVK_ANSI_K):
            return "K"
        case UInt32(kVK_ANSI_L):
            return "L"
        case UInt32(kVK_ANSI_M):
            return "M"
        case UInt32(kVK_ANSI_N):
            return "N"
        case UInt32(kVK_ANSI_O):
            return "O"
        case UInt32(kVK_ANSI_P):
            return "P"
        case UInt32(kVK_ANSI_Q):
            return "Q"
        case UInt32(kVK_ANSI_R):
            return "R"
        case UInt32(kVK_ANSI_S):
            return "S"
        case UInt32(kVK_ANSI_T):
            return "T"
        case UInt32(kVK_ANSI_U):
            return "U"
        case UInt32(kVK_ANSI_V):
            return "V"
        case UInt32(kVK_ANSI_W):
            return "W"
        case UInt32(kVK_ANSI_X):
            return "X"
        case UInt32(kVK_ANSI_Y):
            return "Y"
        case UInt32(kVK_ANSI_Z):
            return "Z"
        default:
            return "Key(\(keyCode))"
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let hotKeyChanged = Notification.Name("hotKeyChanged")
}
