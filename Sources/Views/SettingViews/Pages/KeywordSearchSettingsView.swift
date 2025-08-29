import SwiftUI

// MARK: - 关键词搜索设置视图
struct KeywordSearchSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingItem: KeywordSearchItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerView
                KeywordSearchInfoCard()
                Divider()
                searchItemsSection
            }
            .padding(32)
        }
        .sheet(isPresented: $showingAddSheet) {
            KeywordSearchItemEditView(
                item: nil,
                onSave: { newItem in
                    addKeywordSearchItem(newItem)
                }
            )
        }
        .sheet(item: $editingItem) { item in
            KeywordSearchItemEditView(
                item: item,
                onSave: { updatedItem in
                    updateKeywordSearchItem(updatedItem)
                }
            )
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关键词搜索")
                .font(.title)
                .fontWeight(.bold)
            Text("管理自定义搜索引擎和快速搜索关键词")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var searchItemsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            KeywordSearchListHeader {
                showingAddSheet = true
            }

            if configManager.config.modes.keywordModeConfig?.items.isEmpty ?? true {
                KeywordSearchEmptyView()
            } else {
                searchItemsList
            }
        }
    }

    private var searchItemsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(configManager.config.modes.keywordModeConfig?.items ?? []) { item in
                KeywordSearchItemRow(
                    item: item,
                    onEdit: {
                        editingItem = item
                    },
                    onDelete: {
                        removeKeywordSearchItem(item)
                    }
                )
            }
        }
    }

    private func addKeywordSearchItem(_ item: KeywordSearchItem) {
        var config = configManager.config
        if config.modes.keywordModeConfig == nil {
            config.modes.keywordModeConfig = KeywordModeConfig(items: [])
        }
        config.modes.keywordModeConfig?.items.append(item)
        configManager.config = config
        configManager.saveConfig()
    }

    private func updateKeywordSearchItem(_ updatedItem: KeywordSearchItem) {
        var config = configManager.config
        if let index = config.modes.keywordModeConfig?.items.firstIndex(where: {
            $0.id == updatedItem.id
        }) {
            config.modes.keywordModeConfig?.items[index] = updatedItem
            configManager.config = config
            configManager.saveConfig()
        }
    }

    private func removeKeywordSearchItem(_ item: KeywordSearchItem) {
        var config = configManager.config
        config.modes.keywordModeConfig?.items.removeAll { $0.id == item.id }
        configManager.config = config
        configManager.saveConfig()
    }
}
