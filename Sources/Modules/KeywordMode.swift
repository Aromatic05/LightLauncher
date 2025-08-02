import Foundation
import SwiftUI
import Combine

@MainActor
final class KeywordModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = KeywordModeController()
    private override init() { super.init() }

    // 1. 身份与元数据
    // prefix 现在是给框架看的元数据，控制器内部逻辑不再依赖它
    let mode: LauncherMode = .keyword
    let prefix: String? = "."
    let displayName: String = "Keyword Search"
    let iconName: String = "magnifyingglass"
    let placeholder: String = "输入关键字或直接搜索..." // 占位符可以更通用
    let modeDescription: String? = "通过自定义关键字或直接搜索"

    // 2. 状态属性
    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet { dataDidChange.send() }
    }
    @Published var currentQuery: String = "" {
        didSet { updateResults(for: currentQuery) }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 3. 核心逻辑
    func handleInput(arguments: String) {
        self.currentQuery = arguments
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0, index < displayableItems.count else { return false }
        
        let selectedItem = displayableItems[index]
        
        if let item = selectedItem as? ActionableSearchItem {
            guard !item.query.isEmpty else { return false }
            return WebUtils.performWebSearch(query: item.query, encoding: String(item.item.spaceEncoding ?? "%20"))
            
        } else if let item = selectedItem as? KeywordSuggestionItem {
            LauncherViewModel.shared.updateQuery(newQuery: ". \(item.item.keyword) ")
            return false
        }
        
        return false
    }

    // 4. 生命周期与UI
    func cleanup() {
        currentQuery = ""
        displayableItems = []
    }

    func makeContentView() -> AnyView {
        AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        ["输入关键字 (如 g) 或直接搜索 (如 githb repos)", "按回车执行搜索"]
    }

    // MARK: - Private Helper Methods
    private func updateResults(for text: String) {
        let (keyword, query) = parse(content: text)

        // 状态A: 正在输入关键字 (内容中没有空格)
        if !text.contains(" ") {
            let allCustomKeywords = ConfigManager.shared.keywordSearchItems
            if text.isEmpty { // 对应刚进入模式，输入为空
                self.displayableItems = allCustomKeywords.map { KeywordSuggestionItem(item: $0) }
            } else {
                let filtered = allCustomKeywords.filter { $0.keyword.lowercased().hasPrefix(text.lowercased()) }
                // 如果过滤后有结果，显示建议；否则，走后备逻辑
                if !filtered.isEmpty {
                    self.displayableItems = filtered.map { KeywordSuggestionItem(item: $0) }
                } else {
                    // 用户可能还在输入一个不存在的关键字，直接提供后备搜索
                    showFallbackSearch(for: text)
                }
            }
        }
        // 状态B: 关键字输入完成，正在输入查询
        else {
            let allCustomKeywords = ConfigManager.shared.keywordSearchItems
            if let matchedItem = allCustomKeywords.first(where: { $0.keyword.lowercased() == keyword.lowercased() }) {
                // 精确匹配到自定义关键字，显示历史记录
                let historyItems = SearchHistoryManager.shared.getMatchingHistory(for: query, category: matchedItem.title)
                let historyDisplayItems: [ActionableSearchItem] = historyItems.map { ActionableSearchItem(item: matchedItem, query: $0.query) }
                self.displayableItems = [ActionableSearchItem(item: matchedItem, query: query)] + historyDisplayItems
            } else {
                // 未匹配到，使用后备搜索
                showFallbackSearch(for: text)
            }
        }
        
        dataDidChange.send()
    }
    
    private func showFallbackSearch(for fullQuery: String) {
        let googleSearchItem = KeywordSearchItem(
            title: "Google",
            url: "https://www.google.com/search?q={query}",
            keyword: "google",
            icon: "google.png",
            spaceEncoding: "+"
        )
        
        self.displayableItems = [ActionableSearchItem(item: googleSearchItem, query: fullQuery)]
    }
    
    /// 辅助函数：解析内容，分离出关键字和查询词。
    private func parse(content: String) -> (keyword: String, query: String) {
        if let firstSpaceIndex = content.firstIndex(of: " ") {
            let keyword = String(content[..<firstSpaceIndex])
            let query = String(content[content.index(after: firstSpaceIndex)...])
            return (keyword, query)
        } else {
            return (content, "")
        }
    }
}