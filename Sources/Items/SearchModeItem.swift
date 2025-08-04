import SwiftUI

private func loadIcon(named iconName: String?) -> NSImage? {
    guard let iconName = iconName, !iconName.isEmpty else {
        return NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: "Default search icon")
    }
    if let resourceURL = Bundle.module.url(
        forResource: (iconName as NSString).deletingPathExtension,
        withExtension: (iconName as NSString).pathExtension),
        let bundleIcon = NSImage(contentsOf: resourceURL)
    {
        return bundleIcon
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    let iconFullPath = home.appendingPathComponent(".config/LightLauncher/icons/")
        .appendingPathComponent(iconName).path
    if let userIcon = NSImage(contentsOfFile: iconFullPath) {
        return userIcon
    }
    return NSImage(
        systemSymbolName: "magnifyingglass", accessibilityDescription: "Default search icon")
}

struct KeywordSuggestionItem: DisplayableItem {
    let item: KeywordSearchItem
    var id: String { item.keyword }
    var title: String { item.keyword }
    var subtitle: String? { item.title }
    var icon: NSImage? { loadIcon(named: item.icon) }
    @ViewBuilder @MainActor func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(
            KeywordRowView(
                keyword: title, title: subtitle ?? "", icon: icon, isSelected: isSelected))
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: KeywordSuggestionItem, rhs: KeywordSuggestionItem) -> Bool {
        lhs.id == rhs.id
    }
    @MainActor
    func executeAction() -> Bool {
        LauncherViewModel.shared.updateQuery(newQuery: ". \(item.keyword) ")
        return false
    }
}

struct ActionableSearchItem: DisplayableItem {
    let item: KeywordSearchItem
    let query: String
    var id: String { item.keyword + query }
    var title: String {
        query.isEmpty ? item.title : item.title.replacingOccurrences(of: "{query}", with: query)
    }
    var subtitle: String? { "使用 \(item.title) 搜索: \(query)" }
    var icon: NSImage? { loadIcon(named: item.icon) }
    @ViewBuilder @MainActor func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(
            KeywordRowView(
                keyword: title, title: subtitle ?? "", icon: icon, isSelected: isSelected))
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ActionableSearchItem, rhs: ActionableSearchItem) -> Bool {
        lhs.id == rhs.id
    }
    @MainActor
    func executeAction() -> Bool {
        guard !query.isEmpty else { return false }
        return WebUtils.performWebSearch(
            query: query, encoding: String(item.spaceEncoding ?? "%20"),
            searchEngine: item.url)
    }
}

struct CurrentQueryItem: DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SearchCurrentQueryView(query: title, isSelected: isSelected))
    }
    let id = UUID()
    let title: String
    var subtitle: String? { "当前搜索" }
    var icon: NSImage? { nil }
    @MainActor
    func executeAction() -> Bool {
        return WebUtils.performWebSearch(query: title)
    }
}

// MARK: - 搜索历史项
struct SearchHistoryItem: Codable, Identifiable, Hashable, DisplayableItem {
    let id: UUID
    let query: String
    let timestamp: Date
    let category: String  // 使用 'category' 代替 'searchEngine'，更具通用性

    // DisplayableItem 协议实现
    var title: String { query }
    var subtitle: String? { category }  // 副标题可以直接显示类别
    var icon: NSImage? {
        // 未来可以根据 category 返回不同图标
        return NSImage(
            systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
    }

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(
            SearchHistoryRowView(
                item: self, isSelected: isSelected, index: index,
                onDelete: {
                    SearchHistoryManager.shared.removeSearch(item: self)
                }))
    }

    // 初始化方法也更新参数名
    init(query: String, category: String) {
        self.id = UUID()
        self.query = query
        self.timestamp = Date()
        self.category = category
    }
    @MainActor
    func executeAction() -> Bool {
        return WebUtils.performWebSearch(query: query)
    }
}
