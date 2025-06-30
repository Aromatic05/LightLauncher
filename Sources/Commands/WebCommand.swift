import Foundation
import AppKit

// MARK: - 网页打开命令处理器
@MainActor
class WebCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/w"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/w" else { return false }
        viewModel.switchToWebMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 提取实际的搜索文本（去掉 "/w " 前缀）
        let webText = text.hasPrefix("/w ") ? String(text.dropFirst(3)) : text
        viewModel.updateWebResults(query: webText)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .web else { return false }
        
        // 如果有浏览器项目可选择，优先选择浏览器项目
        if !viewModel.browserItems.isEmpty && index < viewModel.browserItems.count {
            let selectedItem = viewModel.browserItems[index]
            return openBrowserItem(selectedItem, in: viewModel)
        }
        
        // 否则处理直接输入的URL
        let urlText = viewModel.searchText.hasPrefix("/w ") ? 
            String(viewModel.searchText.dropFirst(3)) : viewModel.searchText
        
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return openWebsite(urlText: urlText, in: viewModel)
    }
    
    private func openBrowserItem(_ item: BrowserItem, in viewModel: LauncherViewModel) -> Bool {
        guard let url = URL(string: item.url) else { return false }
        NSWorkspace.shared.open(url)
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func openWebsite(urlText: String, in viewModel: LauncherViewModel) -> Bool {
        let cleanText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 首先尝试直接解析为URL
        if let url = URL(string: cleanText), url.scheme != nil {
            NSWorkspace.shared.open(url)
            viewModel.resetToLaunchMode()
            return true
        }
        
        // 如果不是完整URL，检查是否是域名
        if isDomainName(cleanText) {
            if let url = URL(string: "https://\(cleanText)") {
                NSWorkspace.shared.open(url)
                viewModel.resetToLaunchMode()
                return true
            }
        }
        
        // 如果都不是，作为搜索处理
        let encodedQuery = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanText
        let searchURL = getDefaultSearchEngine().replacingOccurrences(of: "{query}", with: encodedQuery)
        
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
            viewModel.resetToLaunchMode()
            return true
        }
        
        return false
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
    
    private func isDomainName(_ text: String) -> Bool {
        // 简单的域名检测：包含点且不包含空格
        return text.contains(".") && !text.contains(" ") && !text.hasPrefix(".")
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    func switchToWebMode() {
        mode = .web
        selectedIndex = 0
        
        // 加载浏览器数据
        self.getBrowserDataManager().loadBrowserData()
        
        // 如果有输入文本，立即搜索；否则显示默认建议
        let webText = self.searchText.hasPrefix("/w ") ? String(self.searchText.dropFirst(3)) : ""
        if !webText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.updateWebResults(query: webText)
        } else {
            // 显示最近访问的书签和历史记录
            self.showDefaultWebSuggestions()
        }
    }
    
    func updateWebResults(query: String) {
        guard mode == .web else { return }
        
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showDefaultWebSuggestions()
        } else {
            browserItems = self.getBrowserDataManager().searchBrowserData(query: query)
        }
        selectedIndex = 0
    }
    
    private func showDefaultWebSuggestions() {
        // 显示最近的书签和历史记录
        browserItems = self.getBrowserDataManager().getDefaultBrowserItems(limit: 10)
    }
}
