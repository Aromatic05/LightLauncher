import SwiftUI

// MARK: - 功能模式设置视图
struct ModeSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager

    private func modeBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { settingsManager.isModeEnabled(key) },
            set: { settingsManager.setMode(key, enabled: $0) }
        )
    }

    private var searchEngineBinding: Binding<String> {
        Binding(
            get: { configManager.config.modes.defaultSearchEngine },
            set: { configManager.updateDefaultSearchEngine($0) }
        )
    }

    private var preferredTerminalBinding: Binding<String> {
        Binding(
            get: { configManager.config.modes.preferredTerminal },
            set: { configManager.updatePreferredTerminal($0) }
        )
    }

    private func enabledBrowserBinding(_ browser: BrowserType) -> Binding<Bool> {
        Binding(
            get: { configManager.getEnabledBrowsers().contains(browser) },
            set: { enabled in
                var enabledBrowsers = configManager.getEnabledBrowsers()
                if enabled {
                    enabledBrowsers.insert(browser)
                } else {
                    enabledBrowsers.remove(browser)
                }
                configManager.updateEnabledBrowsers(enabledBrowsers)
            }
        )
    }

    private func getTerminalDisplayName(_ terminal: String) -> String {
        switch terminal {
        case "ghostty": return "Ghostty"
        case "kitty": return "Kitty"
        case "alacritty": return "Alacritty"
        case "wezterm": return "WezTerm"
        case "iterm2": return "iTerm2"
        case "terminal": return "Terminal.app"
        default: return terminal.capitalized
        }
    }

    private func getBrowserColor(_ browser: BrowserType) -> Color {
        switch browser {
        case .safari:
            return .blue
        case .chrome:
            return .green
        case .edge:
            return .teal
        case .firefox:
            return .orange
        case .arc:
            return .purple
        }
    }

    private var searchEnginePicker: some View {
        Picker("搜索引擎", selection: searchEngineBinding) {
            Text("Google").tag("google")
            Text("百度").tag("baidu")
            Text("必应").tag("bing")
        }
        .pickerStyle(MenuPickerStyle())
    }

    var body: some View {
        StandardSettingsPage(title: "功能模式设置", subtitle: "启用或禁用特定功能模式，并配置相关设置") {
            StandardSettingsSection(title: "模式列表", icon: "slider.horizontal.3", iconColor: .accentColor, spacing: 32) {
                ModeSettingSection(
                    title: KillModeController.shared.settingsTitle("结束进程"),
                    icon: "xmark.circle",
                    iconColor: .red,
                    description: "搜索并结束运行中的应用",
                    showsContent: false,
                    isEnabled: modeBinding("kill")
                ) {}

                Divider()

                ModeSettingSection(
                    title: ClipModeController.shared.settingsTitle("剪贴板模式"),
                    icon: "doc.on.clipboard",
                    iconColor: .purple,
                    description: "管理剪贴板历史和片段，支持复制或直接粘贴",
                    showsContent: false,
                    isEnabled: modeBinding("clip")
                ) {}

                Divider()

                ModeSettingSection(
                    title: PluginModeController.shared.settingsTitle("插件模式"),
                    icon: "puzzlepiece.extension",
                    iconColor: .teal,
                    description: "输入插件命令，调用自定义插件能力",
                    showsContent: false,
                    isEnabled: modeBinding("plugin")
                ) {}

                Divider()

                ModeSettingSection(
                    title: SearchModeController.shared.settingsTitle("网页搜索"),
                    icon: "globe",
                    iconColor: .blue,
                    description: "使用默认搜索引擎搜索网络内容",
                    isEnabled: modeBinding("search")
                ) {
                    HStack {
                        Text("默认搜索引擎：")
                            .font(.subheadline)
                        searchEnginePicker
                    }
                }

                Divider()

                ModeSettingSection(
                    title: WebModeController.shared.settingsTitle("网页打开"),
                    icon: "safari",
                    iconColor: .green,
                    description: "快速打开网站或 URL，支持书签和历史记录",
                    isEnabled: modeBinding("web")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("浏览器数据源")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(BrowserType.allCases, id: \.self) { browser in
                                if browser.isInstalled {
                                    HStack {
                                        Toggle(
                                            browser.displayName,
                                            isOn: enabledBrowserBinding(browser)
                                        )
                                        .toggleStyle(SwitchToggleStyle())

                                        Spacer()

                                        Circle()
                                            .fill(getBrowserColor(browser))
                                            .frame(width: 8, height: 8)
                                    }
                                } else {
                                    HStack {
                                        Text(browser.displayName)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("未安装")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        HStack {
                            Text("默认搜索引擎：")
                                .font(.subheadline)
                            searchEnginePicker
                        }
                    }
                }

                Divider()

                ModeSettingSection(
                    title: TerminalModeController.shared.settingsTitle("终端执行"),
                    icon: "terminal",
                    iconColor: .orange,
                    description: "输入终端命令，并在所选终端应用中执行",
                    isEnabled: modeBinding("terminal")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("首选终端：")
                                .font(.subheadline)
                            Picker(
                                "终端应用",
                                selection: preferredTerminalBinding
                            ) {
                                Text("自动检测").tag("auto")
                                Text("Terminal.app").tag("terminal")
                                Text("iTerm2").tag("iterm2")
                                Text("Ghostty").tag("ghostty")
                                Text("Kitty").tag("kitty")
                                Text("Alacritty").tag("alacritty")
                                Text("WezTerm").tag("wezterm")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }

                Divider()

                ModeSettingSection(
                    title: FileModeController.shared.settingsTitle("文件管理器"),
                    icon: "folder",
                    iconColor: .blue,
                    description: "浏览文件和文件夹，支持自定义起始路径",
                    isEnabled: modeBinding("file")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        FileBrowserPathSettingsView(configManager: configManager)
                            .frame(maxHeight: 300)
                    }
                }

                Divider()

                SettingRow(
                    icon: "lightbulb",
                    iconColor: .yellow,
                    title: "命令提示",
                    description: "输入 / 时显示可用命令列表",
                    isToggle: true,
                    toggleValue: $settingsManager.showCommandSuggestions
                ) {
                    settingsManager.showCommandSuggestions.toggle()
                }
            }
        }
    }
}
