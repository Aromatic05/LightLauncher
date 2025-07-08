import SwiftUI
import Foundation

// MARK: - 插件设置视图
struct PluginSettingsView: View {
    @State private var selectedPlugin: Plugin?
    @State private var showingPluginFolder = false
    @State private var refreshTrigger = false
    @State private var allPlugins: [Plugin] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("插件管理")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 刷新按钮
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
                    
                    // 打开插件文件夹
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
                
                Text("管理和配置已安装的插件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            Divider()
            
            if allPlugins.isEmpty {
                // 空状态
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
                        
                        // 创建目录（如果不存在）
                        try? FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(pluginsDir)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                HStack(spacing: 0) {
                    // 左侧插件列表
                    VStack(alignment: .leading, spacing: 0) {
                        // 插件列表标题
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
                        
                        Divider()
                        
                        // 插件列表
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
        }
        .onAppear {
            Task {
                await loadPlugins()
                // 选择第一个插件
                if selectedPlugin == nil && !allPlugins.isEmpty {
                    selectedPlugin = allPlugins.first
                }
            }
        }
        .onChange(of: refreshTrigger) { _ in
            // 刷新后重新选择插件
            if let currentName = selectedPlugin?.name {
                selectedPlugin = allPlugins.first { $0.name == currentName }
            }
        }
    }
    
    @MainActor
    private func loadPlugins() async {
        let pluginManager = PluginManager.shared
        await pluginManager.initialize()
        allPlugins = pluginManager.getLoadedPlugins()
    }
}

// MARK: - 插件列表项
struct PluginListItem: View {
    let plugin: Plugin
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 插件图标
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 20))
                    .foregroundColor(plugin.isEnabled ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.manifest.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(plugin.command)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 启用/禁用开关
                Toggle("", isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

// MARK: - 插件详情视图
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
            // 标题行
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
            
            // 插件信息
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
                    let configPath = PluginConfigManager.shared.getConfigPath(for: plugin.name)
                    NSWorkspace.shared.open(configPath)
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
                        let defaultConfig = PluginConfig()
                        _ = PluginConfigManager.shared.createDefaultConfig(for: plugin.name, config: defaultConfig)
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
                        await PluginManager.shared.initialize()
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
        if let config: PluginConfig = PluginConfigManager.shared.readConfig(for: plugin.name, type: PluginConfig.self) {
            configData = config.settings.mapValues { $0.value }
            hasConfig = true
        } else {
            configData = [:]
            hasConfig = false
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
