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
    // 兼容旧接口，转发到 StateController
    var browserItems: [BrowserItem] {
        (activeController as? WebStateController)?.browserItems ?? []
    }
    func switchToWebMode() {
        (activeController as? WebStateController)?.activate()
    }
    func updateWebResults(query: String) {
        (activeController as? WebStateController)?.update(for: query)
    }
    func filterBrowserItems(searchText: String) {
        (activeController as? WebStateController)?.update(for: searchText)
    }
    func openWebURL(_ url: String) -> Bool {
        guard let webController = activeController as? WebStateController else { return false }
        return webController.openWebURL(url)
    }
    func openBrowserItem(at index: Int) -> Bool {
        guard let webController = activeController as? WebStateController else { return false }
        return webController.openBrowserItem(at: index)
    }
    func extractCleanWebText() -> String {
        (activeController as? WebStateController)?.extractCleanWebText(searchText) ?? ""
    }
    func resetToLaunchMode() {
        mode = .launch
        selectedIndex = 0
        // 可根据需要清理其它模式状态
    }
}

// MARK: - 网页模式处理器
@MainActor
class WebModeHandler: ModeHandler {
    let prefix = "/w"
    let mode = LauncherMode.web
    
    func extractSearchText(from text: String) -> String {
        // 要求空格分隔符：/w space searchText
        if text.hasPrefix(prefix + " ") {
            return String(text.dropFirst(prefix.count + 1))
        } else if text == prefix {
            return "" // 只有 /w 前缀时，返回空字符串
        }
        return "" // 如果没有空格分隔符，不进行搜索
    }
    
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

// 网页模式 StateController
@MainActor
class WebStateController: NSObject, ModeStateController {
    @Published var browserItems: [BrowserItem] = []
    let mode: LauncherMode = .web
    var displayableItems: [any DisplayableItem] { browserItems.map { $0 as any DisplayableItem } }
    func activate() {
        browserItems = BrowserDataManager.shared.getDefaultBrowserItems(limit: 10)
    }
    func deactivate() { browserItems = [] }
    func update(for searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            activate()
        } else {
            browserItems = BrowserDataManager.shared.searchBrowserData(query: query)
        }
    }
    func executeAction(at index: Int) -> PostAction? {
        if index == 0 {
            // 当前输入项
            return .hideWindow // 具体行为由 openWebURL 驱动
        } else if index > 0 && index <= browserItems.count {
            let item = browserItems[index - 1]
            if let url = URL(string: item.url) {
                NSWorkspace.shared.open(url)
                return .hideWindow
            }
        }
        return .keepWindowOpen
    }
    func openWebURL(_ url: String) -> Bool {
        let cleanText = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: cleanText), url.scheme != nil {
            NSWorkspace.shared.open(url)
            return true
        }
        if isDomainName(cleanText) {
            if let url = URL(string: "https://\(cleanText)") {
                NSWorkspace.shared.open(url)
                return true
            }
        }
        let encodedQuery = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanText
        let searchURL = getDefaultSearchEngine().replacingOccurrences(of: "{query}", with: encodedQuery)
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }
    func openBrowserItem(at index: Int) -> Bool {
        guard index >= 0 && index < browserItems.count else { return false }
        let item = browserItems[index]
        if let url = URL(string: item.url) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }
    func extractCleanWebText(_ searchText: String) -> String {
        let prefix = "/w "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return text.contains(".") && !text.contains(" ") && !text.hasPrefix(".")
    }
}
