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
        // 文本已经在 MainCommandProcessor 中正确处理过了
        viewModel.updateWebResults(query: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .web else { return false }
        
        let cleanWebText = viewModel.searchText.hasPrefix("/w ") ? 
            String(viewModel.searchText.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines) : 
            viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果选择的是当前输入项（索引0）
        if index == 0 {
            if !cleanWebText.isEmpty {
                return openWebsite(urlText: cleanWebText, in: viewModel)
            }
            // 如果输入文本为空，可以提示用户输入
            return false
        }
        // 如果选择的是浏览器项目（索引1开始）
        else if index > 0 && index <= viewModel.browserItems.count {
            let browserIndex = index - 1 // 转换为浏览器项目的实际索引
            let selectedItem = viewModel.browserItems[browserIndex]
            return openBrowserItem(selectedItem, in: viewModel)
        }
        
        return false
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
    
    func extractCleanWebText() -> String {
        let prefix = "/w "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func filterBrowserItems(searchText: String) {
        if searchText.isEmpty {
            browserItems = []
        } else {
            browserItems = self.getBrowserDataManager().searchBrowserData(query: searchText)
        }
    }
    
    func openWebURL(_ url: String) -> Bool {
        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果不包含协议，默认添加 https://
        if !urlString.contains("://") {
            if urlString.contains(".") {
                // 看起来像是网址
                urlString = "https://" + urlString
            } else {
                // 看起来像是搜索词，使用默认搜索引擎
                return executeWebSearch(urlString)
            }
        }
        
        guard let url = URL(string: urlString) else { return false }
        
        NSWorkspace.shared.open(url)
        resetToLaunchMode()
        return true
    }
    
    func openBrowserItem(at index: Int) -> Bool {
        guard index >= 0 && index < browserItems.count else { return false }
        let item = browserItems[index]
        
        guard let url = URL(string: item.url) else { return false }
        
        NSWorkspace.shared.open(url)
        resetToLaunchMode()
        return true
    }
}

// MARK: - 网页模式处理器
@MainActor
class WebModeHandler: ModeHandler {
    let prefix = "/w"
    let mode = LauncherMode.web
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.switchToWebMode()
        // 更新浏览器项目列表
        let cleanText = viewModel.extractCleanWebText()
        viewModel.filterBrowserItems(searchText: cleanText)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        if index == 0 {
            // 当前输入项
            let cleanText = viewModel.extractCleanWebText()
            return viewModel.openWebURL(cleanText)
        } else {
            // 浏览器项目
            let browserIndex = index - 1
            return viewModel.openBrowserItem(at: browserIndex)
        }
    }
}

// MARK: - 网页命令建议提供器
struct WebCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type after /w to open website or URL",
            "Press Enter to open in browser",
            "Delete /w prefix to return to launch mode", 
            "Press Esc to close"
        ]
    }
}

// MARK: - 自动注册处理器
@MainActor
private let _autoRegisterWebProcessor: Void = {
    let processor = WebCommandProcessor()
    let modeHandler = WebModeHandler()
    ProcessorRegistry.shared.registerProcessor(processor)
    ProcessorRegistry.shared.registerModeHandler(modeHandler)
}()
