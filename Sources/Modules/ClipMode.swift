import AppKit
import Combine
import Foundation

// MARK: - 剪贴板模式控制器
@MainActor
final class ClipModeController: NSObject, ModeStateController, ObservableObject {
    typealias RestoreScheduler = (@escaping @Sendable () -> Void) -> Void
    typealias EventPoster = @Sendable (
        _ source: CGEventSource?,
        _ keyCode: CGKeyCode,
        _ keyDown: Bool,
        _ flags: CGEventFlags
    ) -> Void

    private final class PasteboardRestoreBox: @unchecked Sendable {
        let items: [NSPasteboardItem]
        let pasteboard: NSPasteboard

        init(items: [NSPasteboardItem], pasteboard: NSPasteboard) {
            self.items = items
            self.pasteboard = pasteboard
        }

        @MainActor
        func restore() {
            ClipModeController.restorePasteboardItems(items, to: pasteboard)
        }
    }

    /// 是否为片段模式
    @Published var isSnippetMode: Bool = false {
        didSet {
            guard isSnippetMode != oldValue else { return }
            handleInput(arguments: "")
        }
    }
    static let shared = ClipModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation
    // 1. 身份与元数据
    let mode: LauncherMode = .clip
    let prefix: String? = "/v"
    var displayName: String {
        isSnippetMode ? "片段" : "剪贴板历史"
    }
    let commandDisplayName: String = "剪贴板历史"
    let iconName: String = "doc.on.clipboard"
    var placeholder: String {
        isSnippetMode ? "搜索片段..." : "搜索剪贴板历史..."
    }
    var modeDescription: String? {
        isSnippetMode
            ? "浏览、复制或直接粘贴已保存的片段"
            : "浏览剪贴板历史，支持文本和文件"
    }

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        displayableItems = displayableItems(for: arguments)
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    var interceptedKeys: Set<KeyEvent> {
        return [.enterWithModifiers(modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue))]
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .optionFlagChanged:
            if .optionFlagChanged(isPressed: true) == keyEvent {
                isSnippetMode.toggle()
            }
            return true
        case .enterWithModifiers(modifierRawValue: UInt(NSEvent.ModifierFlags.shift.rawValue)):
            // 处理带修饰键的 Enter
            LauncherViewModel.shared.hideWindow()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
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

    /// 直接粘贴选中内容，而不是仅复制到剪贴板
    func executeInputAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else {
            return false
        }

        guard let text = directInputText(for: displayableItems[index]) else {
            return false
        }

        Self.simulateTextInput(text)
        return (displayableItems[index] as? ClipboardItem)?.payload != .file
    }

    /// 使用临时剪贴板和 Cmd+V 将文本直接粘贴到当前聚焦控件
    static func simulateTextInput(
        _ text: String,
        pasteboard: NSPasteboard = .general,
        restoreScheduler: RestoreScheduler? = nil,
        eventPoster: EventPoster? = nil
    ) {
        guard !text.isEmpty else { return }

        let snapshot = capturePasteboardItems(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
        let postEvent = eventPoster ?? defaultEventPoster
        postEvent(src, 0x37, true, .maskCommand)
        postEvent(src, 9, true, .maskCommand)
        postEvent(src, 9, false, .maskCommand)
        postEvent(src, 0x37, false, [])

        let restoreBox = PasteboardRestoreBox(items: snapshot, pasteboard: pasteboard)
        let scheduler = restoreScheduler ?? defaultRestoreScheduler
        scheduler {
            MainActor.assumeIsolated {
                restoreBox.restore()
            }
        }
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.isSnippetMode = false
        self.displayableItems = []
    }

    func getHelpText() -> [String] {
        let primaryLine = isSnippetMode ? "浏览并复制已保存的片段" : "浏览剪贴板历史"
        let actionLine =
            isSnippetMode
            ? "按 Enter 将选中片段复制到剪贴板"
            : "按 Enter 将选中项目复制到剪贴板"
        let toggleLine =
            isSnippetMode
            ? "按 Option 切回剪贴板历史"
            : "按 Option 在剪贴板历史和片段间切换"
        let filterLine =
            isSnippetMode
            ? "输入关键词过滤片段，按 Esc 退出"
            : "输入关键词过滤历史，按 Esc 退出"

        return [
            primaryLine,
            actionLine,
            "按 Shift+Enter 直接粘贴选中项目",
            toggleLine,
            filterLine,
        ]
    }

    // MARK: - Private Helper Methods

    private func displayableItems(for query: String) -> [any DisplayableItem] {
        if isSnippetMode {
            return filterSnippets(with: query).map { $0 as any DisplayableItem }
        }
        return filterHistory(with: query).map { $0 as any DisplayableItem }
    }

    private func directInputText(for item: any DisplayableItem) -> String? {
        if let clipItem = item as? ClipboardItem {
            return clipItem.directInputText
        }
        if let snippet = item as? SnippetItem {
            return snippet.snippet
        }
        return nil
    }

    private func filterHistory(with query: String) -> [ClipboardItem] {
        let allItems = ClipboardManager.shared.getHistory()
        if query.isEmpty {
            return allItems
        }

        let scoredItems = allItems.compactMap { item -> (ClipboardItem, Double)? in
            switch item.payload {
            case .text:
                guard let str = item.textValue else { return nil }
                let scores: [Double?] = [
                    StringMatcher.calculateWordStartMatch(text: str, query: query),
                    StringMatcher.calculateSubsequenceMatch(text: str, query: query),
                    StringMatcher.calculateFuzzyMatch(text: str, query: query),
                ]
                if let bestScore = scores.compactMap({ $0 }).max() {
                    return (item, bestScore)
                }
            case .file:
                guard let url = item.fileURL else { return nil }
                if url.lastPathComponent.localizedCaseInsensitiveContains(query) {
                    return (item, 10.0)  // Give file matches a high score
                }
            }
            return nil
        }

        return scoredItems.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    nonisolated private static func defaultRestoreScheduler(_ action: @escaping @Sendable () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            action()
        }
    }

    nonisolated private static func defaultEventPoster(
        _ source: CGEventSource?,
        _ keyCode: CGKeyCode,
        _ keyDown: Bool,
        _ flags: CGEventFlags
    ) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    private static func capturePasteboardItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map(copyPasteboardItem(_:))
    }

    private static func restorePasteboardItems(
        _ items: [NSPasteboardItem],
        to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }

    private static func copyPasteboardItem(_ item: NSPasteboardItem) -> NSPasteboardItem {
        let copy = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
            }
        }
        return copy
    }
}
