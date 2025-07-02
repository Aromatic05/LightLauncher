import Foundation

// MARK: - 插件返回的结果项
struct PluginItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String? // SF Symbol 名称或 Base64 图片字符串
    let action: String? // 执行动作的标识符
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, 
         action: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
    
    // MARK: - Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PluginItem, rhs: PluginItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 插件结果集合
struct PluginResult {
    let items: [PluginItem]
    let hasMore: Bool // 是否还有更多结果
    let totalCount: Int? // 总结果数（可选）
    
    init(items: [PluginItem], hasMore: Bool = false, totalCount: Int? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.totalCount = totalCount
    }
    
    var isEmpty: Bool {
        return items.isEmpty
    }
    
    var count: Int {
        return items.count
    }
}
