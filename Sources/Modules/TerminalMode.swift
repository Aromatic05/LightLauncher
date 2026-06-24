import Combine
import Foundation

@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    // 终端命令历史管理器
    let historyManager = TerminalHistoryManager.shared
    static let shared = TerminalModeController()
    private override init() {}

    // MARK: - Dependencies
    /// 唯一的依赖项：终端执行运行时
    let terminalExecutor = TerminalExecutionRuntime.shared

    let mode: LauncherMode = .terminal
    let prefix: String? = ">"
    let displayName: String = "终端执行"
    let iconName: String = "terminal"
    let placeholder: String = "输入要执行的终端命令..."
    let modeDescription: String? = "在终端中执行命令"

    @Published var currentQuery: String = ""

    var displayableItems: [any DisplayableItem] {
        let currentItem = TerminalHistoryItem(command: currentQuery)
        let historyItems = historyManager.getMatchingHistory(for: currentQuery)
        return [currentItem] + historyItems
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    func handleInput(arguments: String) {
        self.currentQuery = arguments
        dataDidChange.send()
    }

    func cleanup() {
        self.currentQuery = ""
        dataDidChange.send()
    }

    func getHelpText() -> [String] {
        let trigger = prefix ?? ">"

        return [
            "在 \(trigger) 后输入终端命令",
            "按 Enter 在终端中执行命令",
            "按 Esc 退出",
        ]
    }

    // MARK: - 历史记录管理操作
    /// 删除历史项并刷新视图
    func deleteHistoryItem(_ item: TerminalHistoryItem) {
        historyManager.removeCommand(item: item)
        self.currentQuery = self.currentQuery
        dataDidChange.send()
    }
    func clearHistory() {
        historyManager.clearHistory()
        self.currentQuery = self.currentQuery
        dataDidChange.send()
    }
}
