import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 剪切板模式控制器
@MainActor
final class ClipModeController: NSObject, ModeStateController, ObservableObject {
    /// 是否为片段模式
    @Published var isSnippetMode: Bool = false {
        didSet {
            handleInput(arguments: "")
        }
    }
    static let shared = ClipModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation
    // 1. 身份与元数据
    let mode: LauncherMode = .clip
    let prefix: String? = "/v"
    let displayName: String = "Clipboard History"
    let iconName: String = "doc.on.clipboard"
    let placeholder: String = "Search clipboard history..."
    let modeDescription: String? = "Browse and paste clipboard history (text/files)"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        if isSnippetMode {
            let items = filterSnippets(with: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            let items = filterHistory(with: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    var interceptedKeys: Set<KeyEvent> {
        return [.enterWithModifiers(modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue))]
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .commandFlagChanged:
            if .commandFlagChanged(isPressed: true) == keyEvent {
                isSnippetMode.toggle()
            }
            return true
        case .enterWithModifiers(modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue)):
            // 处理带修饰键的 Enter
            NotificationCenter.default.post(name: .hideWindow, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                _ = self.executeInputAction(at: LauncherViewModel.shared.selectedIndex)
            }
            return true
        default:
            return false
        }
    }

    private func filterSnippets(with query: String) -> [SnippetItem] {
        let allItems = SnippetManager.shared.getSnippets()
        if query.isEmpty {
            return allItems
        }
        // 简单模糊匹配，可根据需要扩展
        return SnippetManager.shared.searchSnippets(query: query)
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else {
            return false
        }
        let item = self.displayableItems[index]
        if let clipItem = item as? ClipboardItem {
            if let historyIndex = ClipboardManager.shared.getHistory().firstIndex(of: clipItem) {
                ClipboardManager.shared.removeItem(at: historyIndex)
            }
            switch clipItem {
            case .text(let str):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(str, forType: .string)
            case .file(let url):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
            }
            return true
        } else if let snippet = item as? SnippetItem {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet.snippet, forType: .string)
            return true
        }
        return false
    }


    /// 直接输入选中内容（使用辅助功能 API），而不是复制到剪切板
    func executeInputAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else {
            return false
        }
        let item = self.displayableItems[index]
        if let clipItem = item as? ClipboardItem {
            switch clipItem {
            case .text(let str):
                Self.simulateTextInput(str)
                return true
            case .file(let url):
                Self.simulateTextInput(url.path)
                return false
            }
        } else if let snippet = item as? SnippetItem {
            Self.simulateTextInput(snippet.snippet)
            return true
        }
        return false
    }

    /// 使用 Accessibility API 将文本直接输入到当前聚焦控件
    private static func simulateTextInput(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        let src = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9 // 'v' 键
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true) // Command
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.displayableItems = []
    }

    func makeContentView() -> AnyView {
        return AnyView(ClipModeView(viewModel: LauncherViewModel.shared))
        // else {
        //     let hasSearchText = !LauncherViewModel.shared.searchText.isEmpty
        //     return AnyView(EmptyStateView(
        //         icon: "doc.on.clipboard",
        //         iconColor: hasSearchText ? .secondary.opacity(0.5) : .accentColor.opacity(0.7),
        //         title: hasSearchText ? "未找到剪切板内容" : "暂无剪切板历史",
        //         description: hasSearchText ? "请尝试其他搜索关键词" : nil,
        //         helpTexts: getHelpText()
        //     ))
        // }
    }

    func getHelpText() -> [String] {
        return [
            "Browse and paste clipboard history",
            "Press Enter to copy the selected item",
            "Type to filter history, press Esc to exit"
        ]
    }

    // MARK: - Private Helper Methods
    
    private func filterHistory(with query: String) -> [ClipboardItem] {
        let allItems = ClipboardManager.shared.getHistory()
        if query.isEmpty {
            return allItems
        }
        
        let scoredItems = allItems.compactMap { item -> (ClipboardItem, Double)? in
            switch item {
            case .text(let str):
                let scores: [Double?] = [
                    StringMatcher.calculateWordStartMatch(text: str, query: query),
                    StringMatcher.calculateSubsequenceMatch(text: str, query: query),
                    StringMatcher.calculateFuzzyMatch(text: str, query: query)
                ]
                if let bestScore = scores.compactMap({ $0 }).max() {
                    return (item, bestScore)
                }
            case .file(let url):
                if url.lastPathComponent.localizedCaseInsensitiveContains(query) {
                    return (item, 10.0) // Give file matches a high score
                }
            }
            return nil
        }
        
        return scoredItems.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}
