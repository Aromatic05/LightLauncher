import Foundation
import SwiftUI

// MARK: - 插件设置视图
struct PluginSettingsView: View {
    @State private var allPlugins: [Plugin] = []
    private let fileAccess = FileAccessService.shared
    private let pluginManager = PluginManager.shared
    private let pluginModeController = PluginModeController.shared

    private var pluginsDirectoryURL: URL {
        fileAccess.homeDirectory.appendingPathComponent(".config/LightLauncher/plugins")
    }

    var body: some View {
        StandardSettingsPage(title: "插件管理", subtitle: "统一管理已安装插件、配置文件和启用状态") {
            StandardSettingsSection(
                title: "已安装插件",
                icon: "puzzlepiece.extension",
                iconColor: .teal,
                count: allPlugins.count,
                countLabel: "个"
            ) {
                SettingsCard {
                    HStack(spacing: 12) {
                        Button("刷新插件列表") {
                            Task { await refreshPlugins() }
                        }
                        .buttonStyle(.bordered)

                        Button("打开插件文件夹") {
                            openPluginsDirectory(ensureDirectory: true)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if allPlugins.isEmpty {
                    EmptyStatePlaceholder(
                        icon: "puzzlepiece.extension",
                        title: "暂无插件",
                        description: "将插件文件夹放入 ~/.config/LightLauncher/plugins/ 目录",
                        actionTitle: "打开插件文件夹",
                        action: { openPluginsDirectory(ensureDirectory: true) }
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(allPlugins, id: \.name) { plugin in
                            PluginSettingsCard(
                                plugin: plugin,
                                onToggle: { enabled in
                                    Task { await setPluginEnabled(plugin.name, enabled: enabled) }
                                },
                                onReload: {
                                    await refreshPlugins(reloadingPlugins: true)
                                }
                            )
                        }
                    }
                }
            }
        }
        .task { await refreshPlugins() }
    }

    @MainActor
    private func refreshPlugins(reloadingPlugins: Bool = true) async {
        if reloadingPlugins {
            await pluginModeController.reloadPlugins()
        } else {
            await pluginManager.loadAllPlugins()
        }
        allPlugins = pluginManager.getLoadedPlugins()
    }

    @MainActor
    private func setPluginEnabled(_ pluginName: String, enabled: Bool) async {
        if enabled {
            pluginModeController.enablePlugin(pluginName)
        } else {
            pluginModeController.disablePlugin(pluginName)
        }
        allPlugins = pluginManager.getLoadedPlugins()
    }

    private func openPluginsDirectory(ensureDirectory: Bool = false) {
        if ensureDirectory {
            try? fileAccess.ensureDirectory(pluginsDirectoryURL)
        }
        NSWorkspace.shared.open(pluginsDirectoryURL)
    }
}

private struct PluginSettingsCard: View {
    let plugin: Plugin
    let onToggle: (Bool) -> Void
    let onReload: @MainActor () async -> Void

    @State private var configData: [String: Any] = [:]

    private var pluginStatus: (text: String, color: Color) {
        plugin.isEnabled ? ("已启用", .green) : ("已禁用", .orange)
    }

    private var hasConfig: Bool {
        !configData.isEmpty
    }

    var body: some View {
        SettingsCard(contentSpacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(plugin.manifest.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Badge(text: plugin.command, color: .secondary)
                        Badge(text: pluginStatus.text, color: pluginStatus.color)
                    }

                    if !plugin.description.isEmpty {
                        Text(plugin.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { plugin.isEnabled },
                        set: { onToggle($0) }
                    )
                )
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("版本: \(plugin.version)", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("路径: \(plugin.url.lastPathComponent)", systemImage: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if plugin.manifest.shouldHideWindowAfterAction == true {
                    Label("执行后隐藏窗口", systemImage: "eye.slash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("插件配置")
                        .font(.headline)
                    Spacer()
                    Button("编辑配置文件") {
                        PluginConfigManager.shared.ensureConfigExists(for: plugin)
                        let configURL = PluginConfigManager.shared.getConfigPath(for: plugin.name)
                        NSWorkspace.shared.open(configURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if hasConfig {
                    SettingsCard(title: "配置选项", contentSpacing: 8) {
                        ForEach(Array(configData.keys.sorted()), id: \.self) { key in
                            KeyValueRow(
                                key: key,
                                value: "\(String(describing: configData[key] ?? ""))"
                            )
                        }
                    }
                } else {
                    SettingsCard(contentSpacing: 8) {
                        VStack(spacing: 8) {
                            Text("该插件暂无配置文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("创建默认配置") {
                                PluginConfigManager.shared.ensureConfigExists(for: plugin)
                                loadConfig()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("打开插件目录") {
                    NSWorkspace.shared.selectFile(plugin.url.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)

                Button("重新加载插件") {
                    Task { await onReload() }
                }
                .buttonStyle(.bordered)

                Button("删除配置文件") {
                    _ = PluginConfigManager.shared.deleteConfig(for: plugin.name)
                    loadConfig()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
        .task(id: plugin.name) {
            loadConfig()
        }
    }

    private func loadConfig() {
        configData = PluginConfigManager.shared.loadConfig(for: plugin.name).settings.mapValues {
            $0.value
        }
    }
}

// MARK: - 预览
struct PluginSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PluginSettingsView()
            .frame(width: 800, height: 600)
    }
}
