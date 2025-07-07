import SwiftUI

// MARK: - 功能模式设置视图
struct ModeSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var configManager: ConfigManager
    
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("功能模式设置")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("启用或禁用特定功能模式，并配置相关设置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 模式设置组
                VStack(spacing: 32) {
                    // 关闭模式
                    SettingsModeSection(
                        title: "关闭模式 (/k)",
                        icon: "xmark.circle",
                        iconColor: .red,
                        description: "快速关闭运行中的应用程序",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["kill"] ?? true },
                            set: { settingsManager.modeEnabled["kill"] = $0; settingsManager.toggleMode("kill") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("kill")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("在此模式下，你可以：")
                                .font(.headline)
                                .fontWeight(.semibold)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 搜索并选择要关闭的应用")
                                Text("• 使用数字键 1-6 快速选择")
                                Text("• 删除 /k 前缀自动返回启动模式")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 剪贴板模式
                    SettingsModeSection(
                        title: "剪贴板模式 (/c)",
                        icon: "doc.on.clipboard",
                        iconColor: .purple,
                        description: "快速管理和粘贴剪贴板历史",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["clip"] ?? true },
                            set: { settingsManager.modeEnabled["clip"] = $0; settingsManager.toggleMode("clip") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("clip")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("管理最近的剪贴板内容，快速粘贴")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // // 启动模式（不可禁用，仅展示说明）
                    // HStack(alignment: .top, spacing: 16) {
                    //     Image(systemName: "rocket")
                    //         .foregroundColor(.indigo)
                    //         .font(.system(size: 28))
                    //         .frame(width: 36, height: 36)
                    //     VStack(alignment: .leading, spacing: 4) {
                    //         Text("启动模式 (默认)")
                    //             .font(.headline)
                    //         Text("快速启动应用和文件")
                    //             .font(.subheadline)
                    //             .foregroundColor(.secondary)
                    //         Text("输入应用名或文件名即可启动")
                    //             .font(.subheadline)
                    //             .foregroundColor(.secondary)
                    //     }
                    // }
                    // .padding(.vertical, 8)

                    // Divider()

                    // 插件模式
                    SettingsModeSection(
                        title: "插件模式 (/p)",
                        icon: "puzzlepiece.extension",
                        iconColor: .teal,
                        description: "通过插件扩展更多功能",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["plugin"] ?? true },
                            set: { settingsManager.modeEnabled["plugin"] = $0; settingsManager.toggleMode("plugin") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("plugin")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("管理和调用自定义插件")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // 网页搜索模式
                    SettingsModeSection(
                        title: "网页搜索 (/s)",
                        icon: "globe",
                        iconColor: .blue,
                        description: "使用默认搜索引擎搜索网络内容",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["search"] ?? true },
                            set: { settingsManager.modeEnabled["search"] = $0; settingsManager.toggleMode("search") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("search")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("搜索引擎设置：")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("默认搜索引擎：")
                                    .font(.subheadline)
                                Picker("搜索引擎", selection: Binding(
                                    get: { configManager.config.modes.defaultSearchEngine },
                                    set: { configManager.updateDefaultSearchEngine($0) }
                                )) {
                                    Text("Google").tag("google")
                                    Text("百度").tag("baidu")
                                    Text("必应").tag("bing")
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            Text("输入 /s 后空格，然后输入搜索关键词")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 网页打开模式
                    SettingsModeSection(
                        title: "网页打开 (/w)",
                        icon: "safari",
                        iconColor: .green,
                        description: "快速打开网站或 URL，支持书签和历史记录",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["web"] ?? true },
                            set: { settingsManager.modeEnabled["web"] = $0; settingsManager.toggleMode("web") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("web")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("支持的输入格式：")
                                .font(.headline)
                                .fontWeight(.semibold)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 完整 URL：https://example.com")
                                Text("• 域名：example.com")
                                Text("• 关键词：搜索关键词（自动跳转到搜索）")
                                Text("• 书签和历史记录：自动匹配显示")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            // 浏览器数据源设置
                            Text("浏览器数据源：")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(BrowserType.allCases, id: \ .self) { browser in
                                    if browser.isInstalled {
                                        HStack {
                                            Toggle(browser.displayName, isOn: Binding(
                                                get: {
                                                    configManager.getEnabledBrowsers().contains(browser)
                                                },
                                                set: { enabled in
                                                    var enabledBrowsers = configManager.getEnabledBrowsers()
                                                    if enabled {
                                                        enabledBrowsers.insert(browser)
                                                    } else {
                                                        enabledBrowsers.remove(browser)
                                                    }
                                                    configManager.updateEnabledBrowsers(enabledBrowsers)
                                                }
                                            ))
                                            .toggleStyle(SwitchToggleStyle())
                                            
                                            Spacer()
                                            
                                            // 浏览器状态指示器
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
                            
                            // 搜索引擎设置
                            Text("默认搜索引擎：")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            
                            HStack {
                                Picker("搜索引擎", selection: Binding(
                                    get: { configManager.config.modes.defaultSearchEngine },
                                    set: { configManager.updateDefaultSearchEngine($0) }
                                )) {
                                    Text("Google").tag("google")
                                    Text("百度").tag("baidu")
                                    Text("必应").tag("bing")
                                }
                                .pickerStyle(MenuPickerStyle())
                                
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("书签和历史记录会定期自动更新，支持智能搜索匹配")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // 终端执行模式
                    SettingsModeSection(
                        title: "终端执行 (/t)",
                        icon: "terminal",
                        iconColor: .orange,
                        description: "在终端中执行命令",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["terminal"] ?? true },
                            set: { settingsManager.modeEnabled["terminal"] = $0; settingsManager.toggleMode("terminal") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("terminal")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("终端应用设置：")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Text("首选终端：")
                                    .font(.subheadline)
                                Picker("终端应用", selection: Binding(
                                    get: { configManager.config.modes.preferredTerminal },
                                    set: { configManager.updatePreferredTerminal($0) }
                                )) {
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
                            
                            VStack(alignment: .leading, spacing: 6) {
                                let terminal = configManager.config.modes.preferredTerminal
                                if terminal == "auto" {
                                    Text("• 自动检测系统默认终端应用")
                                    Text("• 如果检测失败，按优先级尝试可用终端")
                                    Text("• 最后降级到后台直接执行")
                                } else if terminal == "terminal" {
                                    Text("• 总是使用 Terminal.app")
                                } else if terminal == "iterm2" {
                                    Text("• 优先使用 iTerm2")
                                    Text("• 如果不可用则降级到系统默认")
                                } else {
                                    Text("• 优先使用 \(getTerminalDisplayName(terminal))")
                                    Text("• 如果不可用则降级到系统默认")
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("注意：请谨慎执行终端命令")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // 文件管理器模式
                    SettingsModeSection(
                        title: "文件管理器 (/o)",
                        icon: "folder",
                        iconColor: .blue,
                        description: "浏览文件和文件夹，支持自定义起始路径",
                        isEnabled: Binding(
                            get: { settingsManager.modeEnabled["file"] ?? true },
                            set: { settingsManager.modeEnabled["file"] = $0; settingsManager.toggleMode("file") }
                        ),
                        onToggle: {
                            settingsManager.toggleMode("file")
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("功能特点：")
                                .font(.headline)
                                .fontWeight(.semibold)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 可配置多个起始路径，快速访问常用目录")
                                Text("• 按 Enter 打开文件或进入文件夹")
                                Text("• 按 Space 在 Finder 中打开当前选择")
                                Text("• 支持按名称过滤文件和目录")
                                Text("• 显示文件大小和修改时间")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            // 起始路径配置
                            Text("起始路径配置：")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            
                            FileBrowserPathSettingsView(configManager: configManager)
                                .frame(maxHeight: 300)
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("提示：启动文件模式时会显示配置的起始路径列表")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // 命令提示
                    SettingsRow(
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
                
                Spacer()
            }
            .padding(32)
        }
    }
}
