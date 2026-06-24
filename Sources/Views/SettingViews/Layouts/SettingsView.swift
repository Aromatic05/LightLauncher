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
    @Environment(\.dismiss) private var dismiss
    private let tabs: [(SettingsTab, String, String)] = [
        (.general, "通用", "gear"),
        (.permissions, "权限管理", "shield.checkered"),
        (.modes, "功能模式", "slider.horizontal.3"),
        (.directories, "搜索目录", "folder"),
        (.abbreviations, "缩写匹配", "textformat.abc"),
        (.keywordSearch, "关键词搜索", "magnifyingglass"),
        (.customHotKeys, "自定义快捷键", "command"),
        (.snippets, "代码片段", "doc.text"),
        (.plugins, "插件管理", "puzzlepiece.extension"),
        (.about, "关于", "info.circle"),
    ]

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
                        ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                            TabButton(title: tab.1, icon: tab.2, isSelected: selectedTab == tab.0) {
                                selectedTab = tab.0
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Spacer()

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)

                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("配置管理")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            SidebarActionButton(title: "重新加载配置", systemImage: "arrow.clockwise") {
                                configManager.reloadConfig()
                            }
                            SidebarActionButton(title: "编辑配置文件", systemImage: "doc.text") {
                                NSWorkspace.shared.open(configManager.configURL)
                            }
                            SidebarActionButton(title: "打开配置文件夹", systemImage: "folder") {
                                NSWorkspace.shared.selectFile(
                                    configManager.configURL.path, inFileViewerRootedAtPath: "")
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, -4)

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

            switch selectedTab {
            case .general:
                GeneralSettingsView(
                    settingsManager: settingsManager,
                    configManager: configManager
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
