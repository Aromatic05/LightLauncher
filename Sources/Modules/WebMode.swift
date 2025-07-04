import Foundation
import AppKit

// BrowserItem 遵守 DisplayableItem 协议
extension BrowserItem: DisplayableItem {
    var subtitle: String? { url }
    var icon: NSImage? { nil }
}

// MARK: - 网页模式控制器
@MainActor
class WebModeController: NSObject, ModeStateController {
    @Published var browserItems: [BrowserItem] = []
    var prefix: String? { "/w" }
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        browserItems.map { $0 as any DisplayableItem }
    }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/w")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        BrowserDataManager.shared.loadBrowserData()
        browserItems = BrowserDataManager.shared.getDefaultBrowserItems(limit: 10)
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            browserItems = BrowserDataManager.shared.getDefaultBrowserItems(limit: 10)
        } else {
            browserItems = BrowserDataManager.shared.searchBrowserData(query: query)
        }
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        let cleanWebText = viewModel.extractCleanWebText()
        if index == 0 {
            if !cleanWebText.isEmpty {
                return openWebURL(cleanWebText)
            }
            return false
        } else if index > 0 && index <= browserItems.count {
            return openBrowserItem(at: index - 1)
        }
        return false
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        return !text.hasPrefix("/w")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        browserItems = []
    }
    // --- 辅助方法 ---
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

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    // 兼容旧接口，转发到 StateController
    var browserItems: [BrowserItem] {
        (activeController as? WebModeController)?.browserItems ?? []
    }
    func switchToWebMode() {
        if let controller = activeController as? WebModeController {
            controller.enterMode(with: "", viewModel: self)
        }
    }

    func updateWebResults(query: String) {
        if let controller = activeController as? WebModeController {
            controller.handleInput(query, viewModel: self)
        }
    }
    func filterBrowserItems(searchText: String) {
        if let controller = activeController as? WebModeController {
            controller.handleInput(searchText, viewModel: self)
        }
    }
    func openWebURL(_ url: String) -> Bool {
        guard let webController = activeController as? WebModeController else { return false }
        return webController.openWebURL(url)
    }
    func openBrowserItem(at index: Int) -> Bool {
        guard let webController = activeController as? WebModeController else { return false }
        return webController.openBrowserItem(at: index)
    }
    func extractCleanWebText() -> String {
        (activeController as? WebModeController)?.extractCleanWebText(searchText) ?? ""
    }
    func resetToLaunchMode() {
        mode = .launch
        selectedIndex = 0
        // 可根据需要清理其它模式状态
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
