import SwiftUI

struct PluginDetailView: View {
    let plugin: Plugin
    let onReload: @MainActor () async -> Void
    @State private var configData: [String: Any] = [:]
    private var hasConfig: Bool { !configData.isEmpty }
    private var pluginStatus: (text: String, color: Color) { plugin.isEnabled ? ("已启用", .green) : ("已禁用", .orange) }

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
        .task(id: plugin.name) { loadConfig() }
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
                        Badge(text: plugin.command, color: .secondary)
                        Badge(text: pluginStatus.text, color: pluginStatus.color)
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
                if plugin.manifest.shouldHideWindowAfterAction == true {
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
                    .padding(.vertical, 16)
                }
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
                Button("重新加载插件") { Task { await onReload() } }
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
        configData = PluginConfigManager.shared.loadConfig(for: plugin.name).settings.mapValues { $0.value }
    }
}
