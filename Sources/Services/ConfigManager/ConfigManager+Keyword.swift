import Foundation

// 如需YAML支持请确保已集成Yams库

extension ConfigManager {
    // MARK: - KeywordMode 工具函数

    /// 获取所有自定义搜索项
    var keywordSearchItems: [KeywordSearchItem] {
        config.modes.keywordModeConfig?.items ?? []
    }

    /// 通过keyword查找搜索项
    func searchItem(for keyword: String) -> KeywordSearchItem? {
        keywordSearchItems.first { $0.keyword == keyword }
    }

    /// 添加自定义搜索项
    func addKeywordSearchItem(_ item: KeywordSearchItem) {
        var items = config.modes.keywordModeConfig?.items ?? []
        if !items.contains(where: { $0.keyword == item.keyword }) {
            items.append(item)
            config.modes.keywordModeConfig = KeywordModeConfig(items: items)
            saveConfig()
        }
    }

    /// 删除自定义搜索项
    func removeKeywordSearchItem(keyword: String) {
        guard var items = config.modes.keywordModeConfig?.items else { return }
        items.removeAll { $0.keyword == keyword }
        config.modes.keywordModeConfig = KeywordModeConfig(items: items)
        saveConfig()
    }

    /// 更新（替换）自定义搜索项
    func updateKeywordSearchItem(_ item: KeywordSearchItem) {
        var items = config.modes.keywordModeConfig?.items ?? []
        if let idx = items.firstIndex(where: { $0.keyword == item.keyword }) {
            items[idx] = item
            config.modes.keywordModeConfig = KeywordModeConfig(items: items)
            saveConfig()
        }
    }
}

