import Foundation
import AppKit

// MARK: - 网页搜索命令处理器
@MainActor
class SearchCommandProcessor: CommandProcessor {
    private let historyManager = SearchHistoryManager.shared
    
    func canHandle(command: String) -> Bool {
        return command == "/s"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/s" else { return false }
        viewModel.switchToSearchMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 文本已经在 MainCommandProcessor 中正确处理过了
        // 更新搜索历史建议
        let historyItems = historyManager.getMatchingHistory(for: text, limit: 10)
        viewModel.updateSearchHistory(historyItems)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .search else { return false }
        
        let cleanSearchText = viewModel.searchText.hasPrefix("/s ") ? 
            String(viewModel.searchText.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines) : 
            viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果选择的是当前搜索项（索引0）
        if index == 0 {
            if !cleanSearchText.isEmpty {
                return executeWebSearch(query: cleanSearchText, in: viewModel)
            }
            return false
        }
        // 如果选择的是搜索历史项（索引1开始）
        else if index > 0 && index <= viewModel.searchHistory.count {
            let historyIndex = index - 1 // 转换为历史记录的实际索引
            return viewModel.executeSearchHistoryItem(at: historyIndex)
        }
        
        return false
    }
    
    private func executeWebSearch(query: String, in viewModel: LauncherViewModel) -> Bool {
        // 使用默认搜索引擎进行搜索
        let searchEngine = getDefaultSearchEngine()
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = searchEngine.replacingOccurrences(of: "{query}", with: encodedQuery)
        
        guard let url = URL(string: searchURL) else { return false }
        
        // 保存到搜索历史
        let engineName = getDefaultSearchEngineName()
        historyManager.addSearch(query: query, searchEngine: engineName)
        
        NSWorkspace.shared.open(url)
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func getDefaultSearchEngine() -> String {
        let configManager = ConfigManager.shared
        let engine = configManager.config.modes.defaultSearchEngine
        
        switch engine {
        case "baidu":
            return "https://www.baidu.com/s?wd={query}"
        case "bing":
            return "https://www.bing.com/search?q={query}"
        case "google":
            fallthrough
        default:
            return "https://www.google.com/search?q={query}"
        }
    }
    
    private func getDefaultSearchEngineName() -> String {
        let configManager = ConfigManager.shared
        return configManager.config.modes.defaultSearchEngine
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    func switchToSearchMode() {
        mode = .search
        selectedIndex = 0
        
        // 立即加载搜索历史
        let historyManager = SearchHistoryManager.shared
        let searchText = self.searchText.hasPrefix("/s ") ? 
            String(self.searchText.dropFirst(3)) : ""
        let historyItems = historyManager.getMatchingHistory(for: searchText, limit: 10)
        updateSearchHistory(historyItems)
    }
    
    func updateSearchHistory(_ items: [SearchHistoryItem]) {
        searchHistory = items
        // 确保选中索引在有效范围内
        let maxIndex = getCurrentItems().count - 1
        if selectedIndex > maxIndex {
            selectedIndex = 0
        }
    }
    
    func executeSearchHistoryItem(at index: Int) -> Bool {
        guard index >= 0 && index < searchHistory.count else { return false }
        let item = searchHistory[index]
        
        return executeWebSearch(item.query)
    }
    
    func clearSearchHistory() {
        SearchHistoryManager.shared.clearHistory()
        searchHistory = []
    }
    
    func removeSearchHistoryItem(_ item: SearchHistoryItem) {
        SearchHistoryManager.shared.removeSearch(item: item)
        searchHistory = SearchHistoryManager.shared.searchHistory
    }
    
    func extractCleanSearchText() -> String {
        let prefix = "/s "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func executeWebSearch(_ query: String) -> Bool {
        let configManager = ConfigManager.shared
        let engine = configManager.config.modes.defaultSearchEngine
        
        var searchEngine: String
        switch engine {
        case "baidu":
            searchEngine = "https://www.baidu.com/s?wd={query}"
        case "bing":
            searchEngine = "https://www.bing.com/search?q={query}"
        case "google":
            fallthrough
        default:
            searchEngine = "https://www.google.com/search?q={query}"
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = searchEngine.replacingOccurrences(of: "{query}", with: encodedQuery)
        
        guard let url = URL(string: searchURL) else { return false }
        
        // 保存到搜索历史
        SearchHistoryManager.shared.addSearch(query: query, searchEngine: engine)
        
        NSWorkspace.shared.open(url)
        resetToLaunchMode()
        return true
    }
}

// MARK: - 搜索模式处理器
@MainActor
class SearchModeHandler: ModeHandler {
    let prefix = "/s"
    let mode = LauncherMode.search
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.switchToSearchMode()
        viewModel.updateSearchHistory(SearchHistoryManager.shared.searchHistory)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        if index == 0 {
            // 当前搜索项
            let cleanText = viewModel.extractCleanSearchText()
            return viewModel.executeWebSearch(cleanText)
        } else {
            // 历史记录项
            let historyIndex = index - 1
            return viewModel.executeSearchHistoryItem(at: historyIndex)
        }
    }
}

// MARK: - 搜索命令建议提供器
struct SearchCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type after /s to search the web",
            "Press Enter to execute search",
            "Delete /s prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}

// MARK: - 自动注册处理器
@MainActor
private let _autoRegisterSearchProcessor: Void = {
    let processor = SearchCommandProcessor()
    let modeHandler = SearchModeHandler()
    ProcessorRegistry.shared.registerProcessor(processor)
    ProcessorRegistry.shared.registerModeHandler(modeHandler)
}()
