import Foundation
import AppKit
import SwiftUI
import Combine

// 用于展示keyword池（可用前缀列表）
struct KeywordPoolItem: DisplayableItem {
    let keyword: String
    let title: String
    let iconPath: String?
    var id: String { keyword }
    var subtitle: String? { title }
    var icon: NSImage? {
        if let iconPath = iconPath {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let iconFullPath = home.appendingPathComponent(".config/LightLauncher/icons/").appendingPathComponent(iconPath).path
            if let img = NSImage(contentsOfFile: iconFullPath) {
                return img
            }
        }
        // fallback: macOS系统自带的放大镜图标
        return NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
    }
    
    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(KeywordRowView(keyword: keyword, title: title, icon: icon, isSelected: isSelected))
    }
}

@MainActor
final class KeywordModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = KeywordModeController()
    private override init() {}

    // 1. 身份与元数据
    let mode: LauncherMode = .keyword
    let prefix: String? = "."
    let displayName: String = "Keyword Search"
    let iconName: String = "magnifyingglass"
    let placeholder: String = "输入 .keyword 搜索内容..."
    let modeDescription: String? = "通过自定义关键字快速搜索"

    @Published var currentQuery: String = "" {
        didSet {
            dataDidChange.send()
        }
    }
    @Published var matchedItem: KeywordSearchItem?

    /// 展示所有可用keyword池（前缀池）和当前匹配项
    var displayableItems: [any DisplayableItem] {
        let (keyword, _) = extractKeywordAndQuery(from: currentQuery)
        if keyword.isEmpty {
            return ConfigManager.shared.keywordSearchItems.map {
                KeywordPoolItem(keyword: $0.keyword, title: $0.title, iconPath: $0.icon)
            }
        } else if let item = ConfigManager.shared.searchItem(for: keyword) {
            return [KeywordPoolItem(keyword: item.keyword, title: item.title, iconPath: item.icon)]
        } else {
            return [KeywordPoolItem(keyword: keyword, title: "无匹配自定义关键字", iconPath: nil)]
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        self.currentQuery = arguments
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        let (keyword, query) = extractKeywordAndQuery(from: currentQuery)
        guard let item = ConfigManager.shared.searchItem(for: keyword), !query.isEmpty else { return false }
        return performKeywordSearch(item: item, query: query)
    }

    // 3. 生命周期与UI
    func cleanup() {
        currentQuery = ""
    }

    func makeContentView() -> AnyView {
        AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        [
            "以 .keyword 搜索，如 .g hello",
            "按回车执行自定义搜索",
            "Esc 退出"
        ]
    }

    // MARK: - Private Helper Methods

    private func extractKeywordAndQuery(from text: String) -> (String, String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(".") else { return ("", trimmed) }
        let noPrefix = trimmed.dropFirst()
        let parts = noPrefix.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        } else if parts.count == 1 {
            return (String(parts[0]), "")
        } else {
            return ("", "")
        }
    }

    private func performKeywordSearch(item: KeywordSearchItem, query: String) -> Bool {
        let encoding = item.spaceEncoding ?? "+"
        let encodedQuery: String
        switch encoding {
        case "%20":
            encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?.replacingOccurrences(of: "+", with: "%20") ?? query
        case "+": fallthrough
        default:
            encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?.replacingOccurrences(of: "%20", with: "+") ?? query
        }
        let urlString = item.url.replacingOccurrences(of: "{query}", with: encodedQuery)
        guard let url = URL(string: urlString) else { return false }
        NSWorkspace.shared.open(url)
        return true
    }
}
