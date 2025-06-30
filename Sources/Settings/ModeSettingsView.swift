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
                        isEnabled: $settingsManager.isKillModeEnabled,
                        onToggle: {
                            settingsManager.toggleKillMode()
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
                    
                    // 网页搜索模式
                    SettingsModeSection(
                        title: "网页搜索 (/s)",
                        icon: "globe",
                        iconColor: .blue,
                        description: "使用默认搜索引擎搜索网络内容",
                        isEnabled: $settingsManager.isSearchModeEnabled,
                        onToggle: {
                            settingsManager.toggleSearchMode()
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
                        description: "快速打开网站或 URL",
                        isEnabled: $settingsManager.isWebModeEnabled,
                        onToggle: {
                            settingsManager.toggleWebMode()
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
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 终端执行模式
                    SettingsModeSection(
                        title: "终端执行 (/t)",
                        icon: "terminal",
                        iconColor: .orange,
                        description: "在终端中执行命令",
                        isEnabled: $settingsManager.isTerminalModeEnabled,
                        onToggle: {
                            settingsManager.toggleTerminalMode()
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
                    
                    // 命令提示
                    SettingsRow(
                        icon: "lightbulb",
                        iconColor: .yellow,
                        title: "命令提示",
                        description: "输入 / 时显示可用命令列表",
                        isToggle: true,
                        toggleValue: $settingsManager.showCommandSuggestions
                    ) {
                        settingsManager.toggleCommandSuggestions()
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
}
