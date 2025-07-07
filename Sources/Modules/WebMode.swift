import Foundation
import AppKit
import SwiftUI

// MARK: - 网页模式控制器
@MainActor
class WebModeController: NSObject, ModeStateController, ObservableObject  {
    var prefix: String? { "/w" }
    var displayableItems: [any DisplayableItem] = []
       // 元信息属性
    var displayName: String { "Web Open" }
    var iconName: String { "safari" }
    var placeholder: String { "Enter URL or website name..." }
    var modeDescription: String? { "Open a website or URL in your default browser" }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/w")
    }

    // 工具方法：生成“当前输入项+历史项”
    private func makeWebItems(for text: String) -> [BrowserItem] {
        let cleanSearchText = text.hasPrefix("/w ") ?
            String(text.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines) :
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        var items: [BrowserItem] = []
        let searchItem = BrowserItem(
            title: cleanSearchText.isEmpty ? "请输入网址或关键词" : cleanSearchText,
            url: cleanSearchText,
            type: .input,
            source: .safari,
            lastVisited: nil,
            visitCount: 0,
            subtitle: cleanSearchText.isEmpty ? nil : "打开网页或搜索：\(cleanSearchText)",
            iconName: "globe",
            actionHint: "按回车打开网页"
        )
        items.append(searchItem)
        if cleanSearchText.isEmpty {
            items += BrowserDataManager.shared.getDefaultBrowserItems(limit: 10)
        } else {
            items += BrowserDataManager.shared.searchBrowserData(query: cleanSearchText)
        }
        return items
    }

    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        BrowserDataManager.shared.loadBrowserData()
        let items = makeWebItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }

    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let items = makeWebItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }

    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        let cleanWebText = extractCleanWebText(viewModel.searchText)
        if index == 0 {
            if !cleanWebText.isEmpty {
                return openWebURL(cleanWebText)
            }
            return false
        } else if index > 0 && index < self.displayableItems.count {
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
        self.displayableItems = []
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
        guard index >= 0 && index < self.displayableItems.count else { return false }
        guard let item = self.displayableItems[index] as? BrowserItem else { return false }
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

    static func getHelpText() -> [String] {
        return [
            "Type after /w to open website or URL",
            "Press Enter to open in browser",
            "Delete /w prefix to return to launch mode", 
            "Press Esc to close"
        ]
    }

    func updateWebResults(query: String, viewModel: LauncherViewModel) {
        self.handleInput(query, viewModel: viewModel)
    }
    func filterBrowserItems(searchText: String, viewModel: LauncherViewModel) {
        self.handleInput(searchText, viewModel: viewModel)
    }

    // 生成内容视图
    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: viewModel))
        } else {
            return AnyView(WebCommandInputView(searchText: viewModel.searchText))
        }
    }

    // 结果行渲染方法
   func makeRowView(for item: any DisplayableItem, isSelected: Bool, index: Int, viewModel: LauncherViewModel, handleItemSelection: @escaping (Int) -> Void) -> AnyView {
        if let browserItem = item as? BrowserItem {
            return AnyView(BrowserItemRowView(item: browserItem, isSelected: isSelected, index: index))
        }
        return AnyView(EmptyView())
    }
}
