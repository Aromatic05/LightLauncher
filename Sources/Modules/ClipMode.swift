import Foundation
import AppKit
import SwiftUI

// MARK: - 剪切板模式数据
struct ClipModeData: ModeData {
    let items: [ClipboardItem]
    
    var count: Int { items.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }
}

// MARK: - 剪切板模式控制器
@MainActor
class ClipModeController: NSObject, ModeStateController, ObservableObject {
    var displayableItems: [any DisplayableItem] = []
    var prefix: String? { "/v" }

    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/v")
    }
    // 工具方法：生成“当前剪切板项”
    private func makeClipItems(for text: String) -> [ClipboardItem] {
        let allItems = ClipboardManager.shared.getHistory()
        let prefix = "/v"
        let trimmedText: String
        if text.hasPrefix(prefix + " ") {
            trimmedText = String(text.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasPrefix(prefix) {
            trimmedText = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmedText.isEmpty {
            return allItems
        } else {
            let scored: [(ClipboardItem, Double)] = allItems.compactMap { item in
                switch item {
                case .text(let str):
                    let scores: [Double?] = [
                        StringMatcher.calculateWordStartMatch(text: str, query: trimmedText),
                        StringMatcher.calculateSubsequenceMatch(text: str, query: trimmedText),
                        StringMatcher.calculateFuzzyMatch(text: str, query: trimmedText)
                    ]
                    if let best = scores.compactMap({ $0 }).max() {
                        return (item, best)
                    } else {
                        return nil
                    }
                case .file(let url):
                    let name = url.lastPathComponent
                    if name.localizedCaseInsensitiveContains(trimmedText) {
                        return (item, 10.0)
                    } else {
                        return nil
                    }
                }
            }.sorted { $0.1 > $1.1 }
            return scored.map { $0.0 }
        }
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        let items = makeClipItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let items = makeClipItems(for: text)
        self.displayableItems = items.map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else { return false }
        guard let item = self.displayableItems[index] as? ClipboardItem else { return false }
        // 先删除原有项，避免重复（按历史顺序查找）
        if let historyIndex = ClipboardManager.shared.getHistory().firstIndex(of: item) {
            ClipboardManager.shared.removeItem(at: historyIndex)
        }
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
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /v 前缀或切换到其他模式时退出
        return !text.hasPrefix("/v")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        self.displayableItems = []
    }

    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ClipModeResultsView(viewModel: viewModel))
        } else {
            return AnyView(EmptyStateView(mode: .clip, hasSearchText: !viewModel.searchText.isEmpty))
        }
    }

    static func getHelpText() -> [String] {
        return [
            "浏览和粘贴剪切板历史（文本/文件）",
            "回车复制选中项到剪切板",
            "输入过滤文本历史，Esc 返回主模式"
        ]
    }
}

// // MARK: - LauncherViewModel 扩展
// extension LauncherViewModel {
//     // 兼容接口，转发到 StateController
//     var currentClipItems: [ClipboardItem] {
//         displayableItems.compactMap { $0 as? ClipboardItem }
//     }
//     // func switchToClipMode() {
//     //     mode = .clip
//     //     (activeController as? ClipModeController)?.enterMode(with: "", viewModel: self)
//     //     selectedIndex = 0
//     // }
//     func updateClipResults(filter: String?) {
//         (activeController as? ClipModeController)?.handleInput(filter ?? "", viewModel: self)
//         selectedIndex = 0
//     }
//     func getClipItem(at index: Int) -> ClipboardItem? {
//         currentClipItems.indices.contains(index) ? currentClipItems[index] : nil
//     }
// }
