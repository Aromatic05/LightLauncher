import SwiftUI

// MARK: - 自定义快捷键设置视图
struct CustomHotKeySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingHotKey: CustomHotKeyConfig?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerView
                CustomHotKeyInfoCard()
                Divider()
                hotKeysSection
            }
            .padding(32)
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

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义快捷键")
                .font(.title)
                .fontWeight(.bold)
            Text("设置全局快捷键来快速输入文本或执行命令")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var hotKeysSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 列表头（添加按钮）
            HStack {
                Text("快捷键配置")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("添加快捷键")
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if configManager.config.customHotKeys.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "command.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无自定义快捷键")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击\"添加快捷键\"按钮创建您的第一个自定义快捷键")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
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

// MARK: - 自定义快捷键说明卡片
struct CustomHotKeyInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.purple)
                Text("快捷键功能")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("功能说明：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("• 设置全局快捷键来快速输入预设文本")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 可用于邮箱地址、常用短语、代码片段等")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 在任何应用中都可以使用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 20)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
