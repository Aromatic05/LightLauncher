import SwiftUI

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    @StateObject private var hotKeyRecorder = HotKeyRecorder()

    // 本地 HotKey state，从 SettingsManager 同步
    @State private var hotkey: HotKey = HotKey(keyCode: UInt32(kVK_Space), option: true)

    var body: some View {
        SettingsPage {
            PageHeader(title: "通用设置", subtitle: "基础应用配置和快捷键设置")

            VStack(spacing: 32) {
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

                Divider()

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

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "支持的快捷键类型", icon: "info.circle")

                    HStack(alignment: .top, spacing: 20) {
                        HotKeyInfoCard(
                            title: "修饰键组合",
                            icon: "command",
                            iconColor: .blue,
                            examples: ["⌘ + 字母", "⌥ + 数字", "⌃ + 功能键", "多键组合"]
                        )

                        HotKeyInfoCard(
                            title: "单独修饰键",
                            icon: "option",
                            iconColor: .purple,
                            examples: ["右 Command", "右 Option", "左/右 Control", "Shift 键"]
                        )

                        HotKeyInfoCard(
                            title: "功能键",
                            icon: "f.cursive",
                            iconColor: .orange,
                            examples: ["F1 - F12", "Space", "Return", "Escape"]
                        )
                    }
                }
            }
        }
    }

}

struct HotKeyInfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iconColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .settingsCard()
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
