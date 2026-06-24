import SwiftUI

// MARK: - 自定义快捷键设置视图
struct CustomHotKeySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingHotKey: CustomHotKeyConfig?

    var body: some View {
        StandardSettingsPage(title: "自定义快捷键", subtitle: "设置全局快捷键来快速输入文本或执行命令") {
            StandardSettingsSection(title: "快捷键管理", icon: "command", iconColor: .purple) {
                SettingsCard {
                    HStack {
                        Text("快捷键配置")
                            .font(.headline)
                        Spacer()
                        AddButton(title: "添加快捷键", systemImage: "plus") {
                            showingAddSheet = true
                        }
                    }
                }

                hotKeysSection
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomHotKeyEditView(
                hotKey: nil,
                existingHotKeys: configManager.config.customHotKeys,
                onSave: { newHotKey in
                    addCustomHotKey(newHotKey)
                }
            )
        }
        .sheet(item: $editingHotKey) { hotKey in
            CustomHotKeyEditView(
                hotKey: hotKey,
                existingHotKeys: configManager.config.customHotKeys.filter { $0.id != hotKey.id },
                onSave: { updatedHotKey in
                    updateCustomHotKey(updatedHotKey)
                }
            )
        }
    }

    private var hotKeysSection: some View {
        Group {
            if configManager.config.customHotKeys.isEmpty {
                EmptyStatePlaceholder(
                    icon: "command.circle",
                    title: "暂无自定义快捷键",
                    description: "点击\"添加快捷键\"按钮创建您的第一个自定义快捷键"
                )
            } else {
                hotKeysList
            }
        }
    }

    private var hotKeysList: some View {
        LazyVStack(spacing: 12) {
            ForEach(configManager.config.customHotKeys) { hotKey in
                CustomHotKeyCard(
                    hotKey: hotKey,
                    onEdit: {
                        editingHotKey = hotKey
                    },
                    onDelete: {
                        removeCustomHotKey(hotKey)
                    }
                )
            }
        }
    }

    private func addCustomHotKey(_ hotKey: CustomHotKeyConfig) {
        var config = configManager.config
        config.customHotKeys.append(hotKey)
        configManager.config = config
        configManager.saveConfig()
    }

    private func updateCustomHotKey(_ updatedHotKey: CustomHotKeyConfig) {
        var config = configManager.config
        if let index = config.customHotKeys.firstIndex(where: { $0.id == updatedHotKey.id }) {
            config.customHotKeys[index] = updatedHotKey
            configManager.config = config
            configManager.saveConfig()
        }
    }

    private func removeCustomHotKey(_ hotKey: CustomHotKeyConfig) {
        var config = configManager.config
        config.customHotKeys.removeAll { $0.id == hotKey.id }
        configManager.config = config
        configManager.saveConfig()
    }
}
