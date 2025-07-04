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

// MARK: - 剪切板模式控制器
@MainActor
class ClipModeController: NSObject, ModeStateController {
    @Published var currentClipItems: [ClipboardItem] = []
    var prefix: String? { "/v" }
    
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        currentClipItems
    }
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/v")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        currentClipItems = ClipboardManager.shared.getHistory()
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        let allItems = ClipboardManager.shared.getHistory()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        guard index >= 0 && index < currentClipItems.count else { return false }
        let item = currentClipItems[index]
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
        currentClipItems = []
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    // 兼容接口，转发到 StateController
    var currentClipItems: [ClipboardItem] {
        (activeController as? ClipModeController)?.currentClipItems ?? []
    }
    func switchToClipMode() {
        mode = .clip
        (activeController as? ClipModeController)?.enterMode(with: "", viewModel: self)
        selectedIndex = 0
    }
    func updateClipResults(filter: String?) {
        (activeController as? ClipModeController)?.handleInput(filter ?? "", viewModel: self)
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
