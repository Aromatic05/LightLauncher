import SwiftUI

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    @StateObject private var hotKeyRecorder = HotKeyRecorder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用设置")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("基础应用配置和快捷键设置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 设置组
                VStack(spacing: 32) {
                    // 开机自启动
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

                    // 快捷键设置
                    HotKeyCard(
                        title: "全局快捷键",
                        description: "设置全局快捷键来显示/隐藏启动器，在任何应用中都可以使用",
                        icon: "keyboard",
                        iconColor: .blue,
                        recorder: hotKeyRecorder,
                        modifiers: $settingsManager.hotKeyModifiers,
                        keyCode: $settingsManager.hotKeyCode,
                        hasConflict: false,
                        showResetButton: true,
                        onKeyRecorded: { modifiers, keyCode in
                            configManager.updateHotKey(modifiers: modifiers, keyCode: keyCode)
                        },
                        onReset: {
                            configManager.updateHotKey(modifiers: UInt32(optionKey), keyCode: UInt32(kVK_Space))
                        }
                    )

                    Divider()

                    // 快捷键说明 - 横向布局
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("支持的快捷键类型")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        // 横向排列的快捷键类型
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

                Spacer()
            }
            .padding(32)
        }
    }

}
