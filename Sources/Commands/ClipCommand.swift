import Foundation
import AppKit

// MARK: - 剪切板模式数据
struct ClipModeData: ModeData {
    let items: [ClipboardItem]
    
    var count: Int { items.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }
}

// MARK: - 剪切板命令处理器
@MainActor
class ClipCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/v"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/v" else { return false }
        viewModel.switchToClipMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        let cleanText = text.hasPrefix("/v ") ? String(text.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines) : text.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.updateClipResults(filter: cleanText.isEmpty ? nil : cleanText)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .clip else { return false }
        guard let item = viewModel.getClipItem(at: index) else { return false }
        switch item {
        case .text(let str):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str, forType: .string)
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        // 可扩展：自动粘贴、关闭窗口等
        return true
    }
}

// MARK: - 剪切板模式处理器
@MainActor
class ClipModeHandler: ModeHandler {
    let prefix = "/v"
    let mode: LauncherMode = .clip
    
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        // 复用默认实现
        if text.hasPrefix("/") {
            let inputCommand = text.components(separatedBy: " ").first ?? text
            let knownCommands = ["/k", "/s", "/w", "/t", "/o", "/v"]
            let pluginCommands = PluginManager.shared.getAllPlugins().map { $0.command }
            if knownCommands.contains(inputCommand) || pluginCommands.contains(inputCommand) {
                return false
            }
            let allCommands = knownCommands + pluginCommands
            let hasMatchingPrefix = allCommands.contains { command in
                command.hasPrefix(inputCommand) && command != inputCommand
            }
            if hasMatchingPrefix {
                return false
            }
            if !prefix.isEmpty && inputCommand != prefix && !inputCommand.hasPrefix(prefix + " ") {
                return true
            }
        } else {
            if !prefix.isEmpty && !text.hasPrefix(prefix) {
                return true
            }
        }
        return false
    }
    
    func extractSearchText(from text: String) -> String {
        if text.hasPrefix(prefix + " ") {
            return String(text.dropFirst(prefix.count + 1))
        } else if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        viewModel.updateClipResults(filter: text)
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .clip else { return false }
        guard let item = viewModel.getClipItem(at: index) else { return false }
        switch item {
        case .text(let str):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str, forType: .string)
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        return true
    }
}

// MARK: - ClipStateController
@MainActor
class ClipStateController: ModeStateController {
    var currentClipItems: [ClipboardItem] = []
    let mode: LauncherMode = .clip
    
    var displayableItems: [any DisplayableItem] {
        currentClipItems.map { $0 as any DisplayableItem }
    }
    
    func activate() {
        currentClipItems = ClipboardManager.shared.getHistory()
    }
    func deactivate() {
        currentClipItems = []
    }
    func update(for searchText: String) {
        let allItems = ClipboardManager.shared.getHistory()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            currentClipItems = allItems
        } else {
            let scored: [(ClipboardItem, Double)] = allItems.compactMap { item in
                switch item {
                case .text(let str):
                    let scores: [Double?] = [
                        StringMatcher.calculateWordStartMatch(text: str, query: query),
                        StringMatcher.calculateSubsequenceMatch(text: str, query: query),
                        StringMatcher.calculateFuzzyMatch(text: str, query: query)
                    ]
                    if let best = scores.compactMap({ $0 }).max() {
                        return (item, best)
                    } else {
                        return nil
                    }
                case .file(let url):
                    let name = url.lastPathComponent
                    if name.localizedCaseInsensitiveContains(query) {
                        return (item, 10.0)
                    } else {
                        return nil
                    }
                }
            }.sorted { $0.1 > $1.1 }
            currentClipItems = scored.map { $0.0 }
        }
    }
    func executeAction(at index: Int) -> PostAction? {
        guard index >= 0 && index < currentClipItems.count else { return .keepWindowOpen }
        let item = currentClipItems[index]
        switch item {
        case .text(let str):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str, forType: .string)
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        return .hideWindow
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    // 兼容接口，转发到 StateController
    var currentClipItems: [ClipboardItem] {
        (activeController as? ClipStateController)?.currentClipItems ?? []
    }
    func switchToClipMode() {
        mode = .clip
        (activeController as? ClipStateController)?.activate()
        selectedIndex = 0
    }
    func updateClipResults(filter: String?) {
        (activeController as? ClipStateController)?.update(for: filter ?? "")
        selectedIndex = 0
    }
    func getClipItem(at index: Int) -> ClipboardItem? {
        currentClipItems.indices.contains(index) ? currentClipItems[index] : nil
    }
}

// MARK: - 剪切板命令建议
struct ClipCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "浏览和粘贴剪切板历史（文本/文件）",
            "回车复制选中项到剪切板",
            "输入过滤文本历史，Esc 返回主模式"
        ]
    }
}
