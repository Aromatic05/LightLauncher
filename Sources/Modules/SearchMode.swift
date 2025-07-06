import Foundation
import AppKit

// MARK: - 搜索模式控制器
@MainActor
class SearchModeController: NSObject, ModeStateController, ObservableObject {
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var currentQuery: String = ""
    
    var prefix: String? { "/s" }
    
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        var items: [any DisplayableItem] = []
        // 当前输入项作为第一个可显示项
        struct CurrentQueryItem: DisplayableItem {
            let id = UUID()
            let title: String
            var subtitle: String? { "当前搜索" }
            var icon: NSImage? { nil }
        }
        if !currentQuery.isEmpty {
            items.append(CurrentQueryItem(title: currentQuery))
        }
        items.append(contentsOf: searchHistory)
        return items
    }
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/s")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        currentQuery = extractQuery(from: text)
        searchHistory = SearchHistoryManager.shared.getMatchingHistory(for: currentQuery, limit: 10)
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        currentQuery = extractQuery(from: text)
        searchHistory = SearchHistoryManager.shared.getMatchingHistory(for: currentQuery, limit: 10)
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        if index == 0 {
            // 当前搜索项
            let cleanText = currentQuery
            return openSearchURL(for: cleanText)
        } else if index > 0 && index <= searchHistory.count {
            let item = searchHistory[index - 1]
            return openSearchURL(for: item.query)
        }
        return false
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /s 前缀或切换到其他模式时退出
        return !text.hasPrefix("/s")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        searchHistory = []
        currentQuery = ""
    }
    // --- 辅助方法 ---
    private func extractQuery(from text: String) -> String {
        let prefix = "/s "
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    private func openSearchURL(for query: String) -> Bool {
        let engine = ConfigManager.shared.config.modes.defaultSearchEngine
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString: String
        switch engine {
        case "baidu":
            urlString = "https://www.baidu.com/s?wd=\(encodedQuery)"
        case "bing":
            urlString = "https://www.bing.com/search?q=\(encodedQuery)"
        case "google":
            fallthrough
        default:
            urlString = "https://www.google.com/search?q=\(encodedQuery)"
        }
        guard let url = URL(string: urlString) else { return false }
        SearchHistoryManager.shared.addSearch(query: query, searchEngine: engine)
        NSWorkspace.shared.open(url)
        return true
    }

    static func getHelpText() -> [String] {
        return [
            "Type after /s to search the web",
            "Press Enter to execute search",
            "Delete /s prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}
