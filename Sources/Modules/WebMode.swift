import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 网页模式控制器
@MainActor
final class WebModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = WebModeController()
    private override init() {
        BrowserDataManager.shared.loadBrowserData()
    }

    // 1. 身份与元数据
    let mode: LauncherMode = .web
    let prefix: String? = "/w"
    let displayName: String = "Open Web Page"
    let iconName: String = "safari"
    let placeholder: String = "Enter URL or website to open..."
    let modeDescription: String? = "Open a URL or search for a site"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet { dataDidChange.send() }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    @Published private var currentQuery: String = ""

    func handleInput(arguments: String) {
        let query = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentQuery = query 

        var items: [any DisplayableItem] = []
        let inputItem = BrowserItem(
            title: query.isEmpty ? "Enter a URL or search term" : query,
            url: query, type: .input, source: .safari,
            subtitle: query.isEmpty ? nil : "Open or search for: \(query)",
            iconName: "globe"
        )
        items.append(inputItem)

        if query.isEmpty {
            items += BrowserDataManager.shared.getDefaultBrowserItems(limit: 10)
        } else {
            items += BrowserDataManager.shared.searchBrowserData(query: query)
        }

        self.displayableItems = items
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < displayableItems.count,
              let item = displayableItems[index] as? BrowserItem else { return false }
        return openWebURL(item.url)
    }

    func cleanup() {
        self.displayableItems = []
        self.currentQuery = "" // 清理时也要重置
    }

    func makeContentView() -> AnyView {
        return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        return [
            "Type a URL or search term to open",
            "Press Enter to open in your default browser",
            "Press Esc to exit"
        ]
    }

    // MARK: - Private Helper Methods

    private func openWebURL(_ text: String) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return false }
        
        // Try to form a URL directly
        if let url = URL(string: cleanText), url.scheme != nil {
            NSWorkspace.shared.open(url)
            return true
        }
        
        // Try to treat it as a domain name (e.g., "apple.com")
        if isDomainName(cleanText) {
            if let url = URL(string: "https://\(cleanText)") {
                NSWorkspace.shared.open(url)
                return true
            }
        }
        
        // Fallback to searching with the default search engine
        let encodedQuery = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanText
        let searchURLString = getDefaultSearchEngineURL().replacingOccurrences(of: "{query}", with: encodedQuery)
        
        if let url = URL(string: searchURLString) {
            NSWorkspace.shared.open(url)
            return true
        }
        
        return false
    }

    private func isDomainName(_ text: String) -> Bool {
        return text.contains(".") && !text.contains(" ") && !text.hasPrefix(".")
    }
    
    private func getDefaultSearchEngineURL() -> String {
        let engine = ConfigManager.shared.config.modes.defaultSearchEngine
        switch engine {
        case "baidu": return "https://www.baidu.com/s?wd={query}"
        case "bing": return "https://www.bing.com/search?q={query}"
        default: return "https://www.google.com/search?q={query}"
        }
    }
}