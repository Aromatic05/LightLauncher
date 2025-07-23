import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 当前搜索项结构体（文件级）
struct CurrentQueryItem: DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SearchCurrentQueryView(query: title, isSelected: isSelected))
    }
    let id = UUID()
    let title: String
    var subtitle: String? { "当前搜索" }
    var icon: NSImage? { nil }
}

@MainActor
final class SearchModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = SearchModeController()
    private override init() {}
    // 1. 身份与元数据
    let mode: LauncherMode = .search
    let prefix: String? = "/s"
    let displayName: String = "Web Search"
    let iconName: String = "globe"
    let placeholder: String = "Enter search query..."
    let modeDescription: String? = "Search the web with your default engine"

    @Published var currentQuery: String = "" {
        didSet {
            dataDidChange.send()
        }
    }
    
    @Published var searchHistory: [SearchHistoryItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }

    var displayableItems: [any DisplayableItem] {
        var items: [any DisplayableItem] = []
        if !currentQuery.isEmpty {
            items.append(CurrentQueryItem(title: currentQuery))
        }
        items.append(contentsOf: searchHistory)
        return items
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        self.currentQuery = arguments
        self.searchHistory = SearchHistoryManager.shared.getMatchingHistory(for: arguments, limit: 10)
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        if !currentQuery.isEmpty && index == 0 {
            return performWebSearch(for: currentQuery)
        }
        
        let historyIndex = currentQuery.isEmpty ? index : index - 1
        
        guard historyIndex >= 0 && historyIndex < searchHistory.count else { return false }
        
        let item = searchHistory[historyIndex]
        return performWebSearch(for: item.query)
    }
    
    // 3. 生命周期与UI
    func cleanup() {
        searchHistory = []
        currentQuery = ""
    }

    func makeContentView() -> AnyView {
        return AnyView(SearchHistoryView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /s to search the web",
            "Press Enter to execute the search",
            "Press Esc to exit"
        ]
    }

    // MARK: - Private Helper Methods

    private func performWebSearch(for query: String) -> Bool {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        
        let engine = ConfigManager.shared.config.modes.defaultSearchEngine
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        var urlString: String
        switch engine {
        case "baidu": urlString = "https://www.baidu.com/s?wd=\(encodedQuery)"
        case "bing": urlString = "https://www.bing.com/search?q=\(encodedQuery)"
        default: urlString = "https://www.google.com/search?q=\(encodedQuery)"
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        SearchHistoryManager.shared.addSearch(query: query, searchEngine: engine)
        NSWorkspace.shared.open(url)
        return true
    }

    // MARK: - Public Helper Methods
    
    func removeSearchHistoryItem(_ item: SearchHistoryItem) {
        SearchHistoryManager.shared.removeSearch(item: item)
        self.searchHistory.removeAll { $0.id == item.id }
    }
    
    /// 【新增】清空搜索历史记录的方法
    func clearSearchHistory() {
        // 1. 清除持久化存储
        SearchHistoryManager.shared.clearHistory()
        // 2. 清除当前会话的显示列表
        self.searchHistory.removeAll()
    }

    func extractCleanSearchText(from fullText: String) -> String {
        guard let prefix = self.prefix else { return fullText }

        // 检查是否以 "/s " (带空格) 开头
        let prefixWithSpace = prefix + " "
        if fullText.hasPrefix(prefixWithSpace) {
            return String(fullText.dropFirst(prefixWithSpace.count))
        }
        
        // 检查是否只以 "/s" 开头
        if fullText.hasPrefix(prefix) {
            return String(fullText.dropFirst(prefix.count))
        }
        
        // 如果不包含前缀，则返回原始文本
        return fullText
    }
}