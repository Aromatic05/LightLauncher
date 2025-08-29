import SwiftUI

struct PluginDetailView: View {
    let plugin: Plugin
    @State private var configData: [String: Any] = [:]
    @State private var hasConfig = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pluginBasicInfoSection
                Divider()
                pluginConfigSection
                Divider()
                pluginActionsSection
            }
            .padding(32)
        }
        .onAppear {
            loadConfig()
        }
        .onChange(of: plugin.name) { _ in
            loadConfig()
        }
    }

    private var pluginBasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.manifest.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    HStack(spacing: 8) {
                        Text(plugin.command)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        if plugin.isEnabled {
                            Text("已启用")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        } else {
                            Text("已禁用")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
            }
            if !plugin.description.isEmpty {
                Text(plugin.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("版本: \(plugin.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text("路径: \(plugin.url.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let shouldHide = plugin.manifest.shouldHideWindowAfterAction, shouldHide {
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.secondary)
                        Text("执行后隐藏窗口")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var pluginConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("插件配置")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("编辑配置文件") {
                    PluginConfigManager.shared.ensureConfigExists(for: plugin)
                    let configURL = PluginConfigManager.shared.getConfigPath(for: plugin.name)
                    NSWorkspace.shared.open(configURL)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if hasConfig {
                VStack(alignment: .leading, spacing: 8) {
                    Text("配置选项:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(Array(configData.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(describing: configData[key] ?? ""))")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("该插件暂无配置文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("创建默认配置") {
                        PluginConfigManager.shared.ensureConfigExists(for: plugin)
                        loadConfig()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var pluginActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("插件操作")
                .font(.headline)
                .fontWeight(.semibold)
            VStack(spacing: 8) {
                Button("打开插件目录") {
                    NSWorkspace.shared.selectFile(plugin.url.path, inFileViewerRootedAtPath: "")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                Button("重新加载插件") {
                    Task {
                        await PluginManager.shared.reloadPlugins()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                Button("删除配置文件") {
                    _ = PluginConfigManager.shared.deleteConfig(for: plugin.name)
                    loadConfig()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
    }

    private func loadConfig() {
        let config = PluginConfigManager.shared.loadConfig(for: plugin.name)
        if !config.settings.isEmpty {
            configData = config.settings.mapValues { $0.value }
            hasConfig = true
        } else {
            configData = [:]
            hasConfig = false
        }
    }
}
