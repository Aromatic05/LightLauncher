import SwiftUI

// MARK: - 设置选项卡枚举
enum SettingsTab {
    case general
    case permissions
    case modes
    case directories
    case abbreviations
    case keywordSearch
    case customHotKeys
    case snippets
    case plugins
    case about
}

// MARK: - 主设置视图
struct SettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject var configManager = ConfigManager.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var isRecordingHotKey = false
    @State private var tempHotKeyDescription = ""
    @State private var globalMonitor: Any?
    @State private var localMonitor: Any?
    @State private var currentModifiers: UInt32 = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {
            // 左侧选项卡
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Image(systemName: "rocket")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("LightLauncher")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // 选项卡列表
                ScrollView {
                    VStack(spacing: 4) {
                        TabButton(
                            title: "通用",
                            icon: "gear",
                            isSelected: selectedTab == .general
                        ) {
                            selectedTab = .general
                        }

                        TabButton(
                            title: "权限管理",
                            icon: "shield.checkered",
                            isSelected: selectedTab == .permissions
                        ) {
                            selectedTab = .permissions
                        }

                        TabButton(
                            title: "功能模式",
                            icon: "slider.horizontal.3",
                            isSelected: selectedTab == .modes
                        ) {
                            selectedTab = .modes
                        }

                        TabButton(
                            title: "搜索目录",
                            icon: "folder",
                            isSelected: selectedTab == .directories
                        ) {
                            selectedTab = .directories
                        }

                        TabButton(
                            title: "缩写匹配",
                            icon: "textformat.abc",
                            isSelected: selectedTab == .abbreviations
                        ) {
                            selectedTab = .abbreviations
                        }

                        TabButton(
                            title: "关键词搜索",
                            icon: "magnifyingglass",
                            isSelected: selectedTab == .keywordSearch
                        ) {
                            selectedTab = .keywordSearch
                        }

                        TabButton(
                            title: "自定义快捷键",
                            icon: "command",
                            isSelected: selectedTab == .customHotKeys
                        ) {
                            selectedTab = .customHotKeys
                        }

                        TabButton(
                            title: "代码片段",
                            icon: "doc.text",
                            isSelected: selectedTab == .snippets
                        ) {
                            selectedTab = .snippets
                        }

                        TabButton(
                            title: "插件管理",
                            icon: "puzzlepiece.extension",
                            isSelected: selectedTab == .plugins
                        ) {
                            selectedTab = .plugins
                        }

                        TabButton(
                            title: "关于",
                            icon: "info.circle",
                            isSelected: selectedTab == .about
                        ) {
                            selectedTab = .about
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Spacer()

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)

                // 底部操作按钮
                VStack(spacing: 16) {
                    // 配置管理按钮组
                    VStack(spacing: 8) {
                        Text("配置管理")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            Button(action: {
                                configManager.reloadConfig()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .frame(width: 12)
                                    Text("重新加载配置")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                NSWorkspace.shared.open(configManager.configURL)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .frame(width: 12)
                                    Text("编辑配置文件")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(action: {
                                NSWorkspace.shared.selectFile(
                                    configManager.configURL.path, inFileViewerRootedAtPath: "")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .frame(width: 12)
                                    Text("打开配置文件夹")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider()
                        .padding(.horizontal, -4)

                    // 主要操作按钮
                    VStack(spacing: 8) {
                        Button("重置为默认设置") {
                            configManager.resetToDefaults()
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)

                        Button("完成") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)

                        Button("退出应用") {
                            NSApplication.shared.terminate(nil)
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 右侧内容区域
            switch selectedTab {
            case .general:
                GeneralSettingsView(
                    settingsManager: settingsManager,
                    configManager: configManager,
                    isRecordingHotKey: $isRecordingHotKey,
                    tempHotKeyDescription: $tempHotKeyDescription,
                    globalMonitor: $globalMonitor,
                    localMonitor: $localMonitor,
                    currentModifiers: $currentModifiers
                )
            case .permissions:
                PermissionSettingsView()
            case .modes:
                ModeSettingsView(
                    settingsManager: settingsManager,
                    configManager: configManager
                )
            case .directories:
                DirectorySettingsView(configManager: configManager)
            case .abbreviations:
                AbbreviationSettingsView(configManager: configManager)
            case .keywordSearch:
                KeywordSearchSettingsView(configManager: configManager)
            case .customHotKeys:
                CustomHotKeySettingsView(configManager: configManager)
            case .snippets:
                SnippetSettingsView()
            case .plugins:
                PluginSettingsView()
            case .about:
                AboutSettingsView(configManager: configManager)
            }
        }
        .frame(width: 960, height: 740)
        .onAppear {
            settingsManager.checkAutoStartStatus()
        }
    }
}
