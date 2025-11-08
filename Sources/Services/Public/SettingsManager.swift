import Foundation
import ServiceManagement

// 设置管理器
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var isAutoStartEnabled: Bool = false
    @Published var hotKey: HotKey = HotKey(keyCode: UInt32(kVK_Space), option: true)

    // 模式开关（用字典统一管理）
    @Published var modeEnabled: [String: Bool] = [
        "kill": true,
        "search": true,
        "web": true,
        "terminal": true,
        "file": true,
        "clip": true,
        "plugin": true,
        "launch": true,
    ]
    @Published var showCommandSuggestions: Bool = true

    private let userDefaults = UserDefaults.standard

    // 设置键
    private enum Keys {
        static let autoStart = "autoStart"
        static let hotKeyRaw = "hotKeyRaw"
        static let modeEnabled = "modeEnabled"
        static let showCommandSuggestions = "showCommandSuggestions"
    }

    private init() {
        loadSettings()
    }

    // MARK: - 加载和保存设置

    private func loadSettings() {
        isAutoStartEnabled = userDefaults.bool(forKey: Keys.autoStart)
        // Load hotkey raw value
        let raw = UInt32(userDefaults.integer(forKey: Keys.hotKeyRaw))
        if raw != 0 {
            hotKey = HotKey(rawValue: raw)
        } else {
            hotKey = HotKey(keyCode: UInt32(kVK_Space), option: true)
        }
        // 加载模式设置，默认启用
        if let dict = userDefaults.dictionary(forKey: Keys.modeEnabled) as? [String: Bool] {
            modeEnabled.merge(dict) { _, new in new }
        }
        showCommandSuggestions =
            userDefaults.object(forKey: Keys.showCommandSuggestions) as? Bool ?? true
        // nothing else
    }

    private func saveSettings() {
        userDefaults.set(isAutoStartEnabled, forKey: Keys.autoStart)
        userDefaults.set(Int(hotKey.rawValue), forKey: Keys.hotKeyRaw)
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

    func updateHotKey(_ hotKey: HotKey) {
        self.hotKey = hotKey
        saveSettings()

        // 通知 AppDelegate 更新热键
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let hotKeyChanged = Notification.Name("hotKeyChanged")
}
