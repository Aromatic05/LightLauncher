import AppKit
import Combine
import Foundation
import SwiftUI

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

    func cleanup() {
        self.displayableItems = []
        self.currentQuery = ""  // 清理时也要重置
    }

    func makeContentView() -> AnyView {
        return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        return [
            "Type a URL or search term to open",
            "Press Enter to open in your default browser",
            "Press Esc to exit",
        ]
    }
}
