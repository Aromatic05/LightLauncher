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
        
        description += ConfigManager.getKeyName(for: hotKeyCode)
        
        return description
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let hotKeyChanged = Notification.Name("hotKeyChanged")
}
