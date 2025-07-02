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
}

// MARK: - 搜索模式处理器
@MainActor
class SearchModeHandler: ModeHandler {
    let prefix = "/s"
    let mode = LauncherMode.search
    weak var mainProcessor: MainCommandProcessor?
    
    init(mainProcessor: MainCommandProcessor) {
        self.mainProcessor = mainProcessor
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        if let processor = mainProcessor?.getProcessor(for: .search) {
            processor.handleSearch(text: text, in: viewModel)
        }
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return mainProcessor?.getProcessor(for: .search)?.executeAction(at: index, in: viewModel) ?? false
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
