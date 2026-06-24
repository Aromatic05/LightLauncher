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
        SettingsPage {
            PageHeader(title: "功能模式设置", subtitle: "启用或禁用特定功能模式，并配置相关设置")

            VStack(spacing: 32) {
                ModeSettingSection(
                    title: KillModeController.shared.settingsTitle("结束进程"),
                    icon: "xmark.circle",
                    iconColor: .red,
                    description: "搜索并结束运行中的应用",
                    isEnabled: modeBinding("kill")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("在此模式下，你可以：")
                            .font(.headline)
                            .fontWeight(.semibold)
                        BulletList(items: [
                            "搜索并选择要结束的应用",
                            "按 Option 在普通结束和强制结束间切换",
                            "使用数字键 1-6 快速选择",
                            "删除 \(KillModeController.shared.commandReference()) 前缀自动返回启动模式",
                        ])
                    }
                }

                Divider()

                ModeSettingSection(
                    title: ClipModeController.shared.settingsTitle("剪贴板模式"),
                    icon: "doc.on.clipboard",
                    iconColor: .purple,
                    description: "管理剪贴板历史和片段，支持复制或直接粘贴",
                    isEnabled: modeBinding("clip")
                ) {
                    BulletList(items: [
                        "按 Enter 将选中项目复制到剪贴板",
                        "按 Shift+Enter 直接粘贴选中项目",
                        "按 Option 在剪贴板历史和片段间切换",
                    ])
                }

                Divider()

                ModeSettingSection(
                    title: PluginModeController.shared.settingsTitle("插件模式"),
                    icon: "puzzlepiece.extension",
                    iconColor: .teal,
                    description: "输入插件命令，调用自定义插件能力",
                    isEnabled: modeBinding("plugin")
                ) {
                    BulletList(items: [
                        "输入 \(PluginModeController.shared.commandReference()) 查看可用插件",
                        "选择插件后继续输入参数",
                    ])
                }

                Divider()

                ModeSettingSection(
                    title: SearchModeController.shared.settingsTitle("网页搜索"),
                    icon: "globe",
                    iconColor: .blue,
                    description: "使用默认搜索引擎搜索网络内容",
                    isEnabled: modeBinding("search")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("搜索引擎设置：")
                            .font(.headline)
                            .fontWeight(.semibold)

                        HStack {
                            Text("默认搜索引擎：")
                                .font(.subheadline)
                            searchEnginePicker
                        }

                        Text(
                            "输入 \(SearchModeController.shared.commandReference(includeTrailingSpace: true))后输入搜索关键词"
                        )
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        Text("支持的输入格式：")
                            .font(.headline)
                            .fontWeight(.semibold)
                        BulletList(items: [
                            "完整 URL：https://example.com",
                            "域名：example.com",
                            "关键词：搜索关键词（自动跳转到搜索）",
                            "书签和历史记录：自动匹配显示",
                        ])

                        Text("浏览器数据源：")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)

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

                        Text("默认搜索引擎：")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)

                        HStack {
                            Picker(
                                "搜索引擎",
                                selection: searchEngineBinding
                            ) {
                                Text("Google").tag("google")
                                Text("百度").tag("baidu")
                                Text("必应").tag("bing")
                            }
                            .pickerStyle(MenuPickerStyle())

                            Spacer()
                        }

                        InfoCallout(
                            icon: "info.circle",
                            iconColor: .blue,
                            text: "书签和历史记录会定期自动更新，支持智能搜索匹配"
                        )
                        .padding(.top, 8)
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
                        BulletList(items: [
                            "输入 \(TerminalModeController.shared.commandReference(includeTrailingSpace: true))后输入终端命令",
                            "按 Enter 在终端中执行命令",
                        ])

                        Text("终端应用设置：")
                            .font(.headline)
                            .fontWeight(.semibold)

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

                        Text("执行优先级说明：")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)

                        let terminal = configManager.config.modes.preferredTerminal
                        if terminal == "auto" {
                            BulletList(items: [
                                "自动检测系统默认终端应用",
                                "如果检测失败，按优先级尝试可用终端",
                                "最后降级到后台直接执行",
                            ])
                        } else if terminal == "terminal" {
                            BulletList(items: ["总是使用 Terminal.app"])
                        } else if terminal == "iterm2" {
                            BulletList(items: [
                                "优先使用 iTerm2",
                                "如果不可用则降级到系统默认",
                            ])
                        } else {
                            BulletList(items: [
                                "优先使用 \(getTerminalDisplayName(terminal))",
                                "如果不可用则降级到系统默认",
                            ])
                        }

                        InfoCallout(
                            icon: "exclamationmark.triangle",
                            iconColor: .orange,
                            text: "注意：请谨慎执行终端命令",
                            textColor: .orange
                        )
                        .padding(.top, 8)
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
                        Text("功能特点：")
                            .font(.headline)
                            .fontWeight(.semibold)
                        BulletList(items: [
                            "可配置多个起始路径，快速访问常用目录",
                            "按 Enter 打开文件或进入文件夹",
                            "按 Space 在 Finder 中打开当前选择",
                            "支持按名称过滤文件和目录",
                            "显示文件大小和修改时间",
                        ])

                        Text("起始路径配置：")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)

                        FileBrowserPathSettingsView(configManager: configManager)
                            .frame(maxHeight: 300)

                        InfoCallout(
                            icon: "info.circle",
                            iconColor: .blue,
                            text: "提示：启动文件模式时会显示配置的起始路径列表",
                            textColor: .blue
                        )
                        .padding(.top, 8)
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
