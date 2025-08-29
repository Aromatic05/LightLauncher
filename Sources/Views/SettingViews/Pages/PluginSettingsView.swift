import Foundation
import SwiftUI

// MARK: - 插件设置视图
struct PluginSettingsView: View {
    @State private var selectedPlugin: Plugin?
    @State private var showingPluginFolder = false
    @State private var refreshTrigger = false
    @State private var allPlugins: [Plugin] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            headerView

            Divider()

            if allPlugins.isEmpty {
                emptyStateView
            } else {
                pluginListView
            }
        }
        .onAppear {
            Task {
                await loadPlugins()
                if selectedPlugin == nil && !allPlugins.isEmpty {
                    selectedPlugin = allPlugins.first
                }
            }
        }
        .onChange(of: refreshTrigger) { _ in
            if let currentName = selectedPlugin?.name {
                selectedPlugin = allPlugins.first { $0.name == currentName }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("插件管理")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                refreshButton
                openFolderButton
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)

            Text("管理和配置已安装的插件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var refreshButton: some View {
        Button(action: {
            Task {
                await loadPlugins()
            }
            refreshTrigger.toggle()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help("刷新插件列表")
    }

    private var openFolderButton: some View {
        Button(action: {
            let pluginsDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/LightLauncher/plugins")
            NSWorkspace.shared.open(pluginsDir)
        }) {
            Image(systemName: "folder")
                .font(.system(size: 16))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help("打开插件文件夹")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("暂无插件")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("将插件文件夹放入 ~/.config/LightLauncher/plugins/ 目录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("打开插件文件夹") {
                let pluginsDir = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".config/LightLauncher/plugins")

                try? FileManager.default.createDirectory(
                    at: pluginsDir, withIntermediateDirectories: true)
                NSWorkspace.shared.open(pluginsDir)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var pluginListView: some View {
        HStack(spacing: 0) {
            // 左侧插件列表
            VStack(alignment: .leading, spacing: 0) {
                pluginListHeader

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allPlugins, id: \.name) { plugin in
                            PluginListItem(
                                plugin: plugin,
                                isSelected: selectedPlugin?.name == plugin.name,
                                onSelect: {
                                    selectedPlugin = plugin
                                },
                                onToggle: { enabled in
                                    plugin.isEnabled = enabled
                                }
                            )
                        }
                    }
                }
            }
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 右侧插件详情和配置
            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("选择一个插件查看详情")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var pluginListHeader: some View {
        HStack {
            Text("已安装插件")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Text("\(allPlugins.count) 个")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @MainActor
    private func loadPlugins() async {
        let pluginManager = PluginManager.shared
        await pluginManager.loadAllPlugins()
        allPlugins = pluginManager.getLoadedPlugins()
    }
}

// MARK: - 预览
struct PluginSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PluginSettingsView()
            .frame(width: 800, height: 600)
    }
}
