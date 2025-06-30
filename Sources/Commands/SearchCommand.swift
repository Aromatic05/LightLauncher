import Foundation
import AppKit

// MARK: - 网页搜索命令处理器
@MainActor
class SearchCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/s"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/s" else { return false }
        viewModel.switchToSearchMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 在搜索模式下，直接显示搜索文本，不需要过滤
        // 用户按回车时会执行搜索
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .search else { return false }
        
        // 提取搜索文本，去掉 "/s " 前缀
        let searchText = viewModel.searchText.hasPrefix("/s ") ? 
            String(viewModel.searchText.dropFirst(3)) : viewModel.searchText
        
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return executeWebSearch(query: searchText, in: viewModel)
    }
    
    private func executeWebSearch(query: String, in viewModel: LauncherViewModel) -> Bool {
        // 使用默认搜索引擎进行搜索
        let searchEngine = getDefaultSearchEngine()
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = searchEngine.replacingOccurrences(of: "{query}", with: encodedQuery)
        
        guard let url = URL(string: searchURL) else { return false }
        
        NSWorkspace.shared.open(url)
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func getDefaultSearchEngine() -> String {
        // 可以从设置中读取，这里先使用 Google 作为默认
        return "https://www.google.com/search?q={query}"
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    func switchToSearchMode() {
        mode = .search
        selectedIndex = 0
    }
}
