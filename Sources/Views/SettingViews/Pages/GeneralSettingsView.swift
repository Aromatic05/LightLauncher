import SwiftUI

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    @StateObject private var hotKeyRecorder = HotKeyRecorder()

    // 本地 HotKey state，从 SettingsManager 同步
    @State private var hotkey: HotKey = HotKey(keyCode: UInt32(kVK_Space), option: true)

    private var restoreInputMethodBinding: Binding<Bool> {
        Binding(
            get: { configManager.config.restorePreviousInputMethod },
            set: { configManager.updateRestorePreviousInputMethod($0) }
        )
    }

    var body: some View {
        StandardSettingsPage(title: "通用设置", subtitle: "基础应用配置和快捷键设置") {
            StandardSettingsSection(title: "应用行为", icon: "gear", iconColor: .green) {
                VStack(spacing: 16) {
                    SettingRow(
                        icon: "power",
                        iconColor: .green,
                        title: "开机自启动",
                        description: "启动时自动运行 LightLauncher",
                        isToggle: true,
                        toggleValue: $settingsManager.isAutoStartEnabled
                    ) {
                        settingsManager.toggleAutoStart()
                    }

                    SettingRow(
                        icon: "globe",
                        iconColor: .blue,
                        title: "自动切换并恢复输入法",
                        description: "显示启动器时切到英文，关闭后恢复之前输入法",
                        isToggle: true,
                        toggleValue: restoreInputMethodBinding
                    )
                }
            }

            StandardSettingsSection(title: "快捷键设置", icon: "keyboard", iconColor: .blue) {
                HotKeyCard(
                    title: "全局快捷键",
                    description: "设置全局快捷键来显示/隐藏启动器，在任何应用中都可以使用",
                    icon: "keyboard",
                    iconColor: .blue,
                    recorder: hotKeyRecorder,
                    hotkey: $hotkey,
                    hasConflict: false,
                    showResetButton: true,
                    onKeyRecorded: { newHotkey in
                        settingsManager.updateHotKey(newHotkey)
                        configManager.updateHotKey(newHotkey)
                    },
                    onReset: {
                        let defaultHot = HotKey(keyCode: UInt32(kVK_Space), option: true)
                        settingsManager.updateHotKey(defaultHot)
                        configManager.updateHotKey(defaultHot)
                    }
                )
                .onAppear {
                    hotkey = settingsManager.hotKey
                }
                .onChange(of: settingsManager.hotKey) { new in
                    hotkey = new
                }
            }
        }
    }

}
