import Foundation
import AppKit
import SwiftUI

// MARK: - 搜索历史项
struct SearchHistoryItem: Codable, Identifiable, Hashable, @preconcurrency DisplayableItem {
    let id: UUID
    let query: String
    let timestamp: Date
    let searchEngine: String
    var title: String { query }
    var subtitle: String? { searchEngine }
    var icon: NSImage? { nil }

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SearchHistoryRowView(item: self, isSelected: isSelected, index: index, onDelete: {}))
    }
    
    init(query: String, searchEngine: String = "google") {
        self.id = UUID()
        self.query = query
        self.timestamp = Date()
        self.searchEngine = searchEngine
    }
}

// MARK: - 搜索历史管理器
@MainActor
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    
    @Published private(set) var searchHistory: [SearchHistoryItem] = []
    private let maxHistoryCount = 50 // 最多保存50条历史记录
    
    private var historyFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("LightLauncher").appendingPathComponent("search_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 公共方法
    
    /// 添加搜索记录
    func addSearch(query: String, searchEngine: String = "google") {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除相同的历史记录（如果存在）
        searchHistory.removeAll { $0.query.lowercased() == trimmedQuery.lowercased() }
        
        // 添加新记录到开头
        let newItem = SearchHistoryItem(query: trimmedQuery, searchEngine: searchEngine)
        searchHistory.insert(newItem, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// 获取匹配的搜索历史
    func getMatchingHistory(for query: String, limit: Int = 10) -> [SearchHistoryItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedQuery.isEmpty {
            return Array(searchHistory.prefix(limit))
        }
        
        return searchHistory
            .filter { $0.query.lowercased().contains(trimmedQuery) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 清除所有搜索历史
    func clearHistory() {
        searchHistory.removeAll()
        saveHistory()
    }
    
    /// 删除特定的搜索记录
    func removeSearch(item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    // MARK: - 私有方法
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            searchHistory = try JSONDecoder().decode([SearchHistoryItem].self, from: data)
        } catch {
            // 如果加载失败，使用空数组
            searchHistory = []
            print("Failed to load search history: \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            // 确保目录存在
            let directory = historyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(searchHistory)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save search history: \(error)")
        }
    }
}
