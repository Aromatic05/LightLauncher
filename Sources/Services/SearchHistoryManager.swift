import Foundation
import AppKit
import SwiftUI

// MARK: - 搜索历史项
struct SearchHistoryItem: Codable, Identifiable, Hashable, DisplayableItem {
    let id: UUID
    let query: String
    let timestamp: Date
    let category: String // 使用 'category' 代替 'searchEngine'，更具通用性

    // DisplayableItem 协议实现
    var title: String { query }
    var subtitle: String? { category } // 副标题可以直接显示类别
    var icon: NSImage? {
        // 未来可以根据 category 返回不同图标
        return NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
    }

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SearchHistoryRowView(item: self, isSelected: isSelected, index: index, onDelete: {
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
}

// MARK: - 搜索历史管理器
@MainActor
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    
    // (已修改) 使用字典来按类别存储历史记录
    @Published private(set) var history: [String: [SearchHistoryItem]] = [:]
    
    // (已修改) 限制变为每个类别的最大历史记录数
    private let maxHistoryPerCategory = 50
    
    private var historyFileURL: URL {
        // 文件路径和名称保持不变，现在它将存储一个字典
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("LightLauncher").appendingPathComponent("search_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 公共方法 (已重构)
    
    /// (已修改) 添加搜索记录到指定的类别
    func addSearch(query: String, category: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 获取或创建该类别的历史记录数组
        var categoryHistory = history[category] ?? []
        
        // 在当前类别中移除相同的历史记录（如果存在）
        categoryHistory.removeAll { $0.query.lowercased() == trimmedQuery.lowercased() }
        
        // 添加新记录到开头
        let newItem = SearchHistoryItem(query: trimmedQuery, category: category)
        categoryHistory.insert(newItem, at: 0)
        
        // 限制当前类别的历史记录数量
        if categoryHistory.count > maxHistoryPerCategory {
            categoryHistory = Array(categoryHistory.prefix(maxHistoryPerCategory))
        }
        
        // 将更新后的数组存回字典
        history[category] = categoryHistory
        
        saveHistory()
    }
    
    /// (已修改) 获取指定类别下的匹配搜索历史
    func getMatchingHistory(for query: String, category: String, limit: Int = 10) -> [SearchHistoryItem] {
        // 如果该类别没有历史记录，返回空数组
        guard let categoryHistory = history[category] else {
            return []
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedQuery.isEmpty {
            // 如果查询为空，返回该类别最新的记录
            return Array(categoryHistory.prefix(limit))
        }
        
        // 否则，返回该类别下匹配的记录
        return categoryHistory
            .filter { $0.query.lowercased().contains(trimmedQuery) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// (已修改) 删除特定的搜索记录，现在无需传入类别
    func removeSearch(item: SearchHistoryItem) {
        // 从 item 自身获取类别
        let category = item.category
        
        // 检查该类别的历史记录是否存在
        guard var categoryHistory = history[category] else { return }
        
        // 删除匹配的项
        categoryHistory.removeAll { $0.id == item.id }
        
        // 将更新后的数组存回字典
        history[category] = categoryHistory
        
        saveHistory()
    }
    
    /// 清除指定类别的所有搜索历史
    func clearHistory(for category: String) {
        history[category] = nil // 直接移除该键值对
        saveHistory()
    }
    
    /// 清除所有类别的所有历史记录
    func clearAllHistory() {
        history.removeAll()
        saveHistory()
    }
    
    // MARK: - 私有方法 (已更新以支持字典)
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            // (已修改) 解码为字典类型
            history = try JSONDecoder().decode([String: [SearchHistoryItem]].self, from: data)
        } catch {
            history = [:] // 加载失败则使用空字典
            print("Failed to load search history (this is normal on first launch): \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            let directory = historyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            
            // (已修改) 编码整个字典
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save search history: \(error)")
        }
    }
}