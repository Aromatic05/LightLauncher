import SwiftUI
import Combine

@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    // 终端命令历史管理器
    let historyManager = TerminalHistoryManager.shared
    static let shared = TerminalModeController()
    private override init() {}

    // MARK: - Dependencies
    /// 唯一的依赖项：终端执行服务
    let terminalExecutor = TerminalExecutorService.shared

    let mode: LauncherMode = .terminal
    let prefix: String? = ">"
    let displayName: String = "Terminal"
    let iconName: String = "terminal"
    let placeholder: String = "Enter terminal command to execute..."
    let modeDescription: String? = "Execute shell commands"

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

    func makeContentView() -> AnyView {
        return AnyView(TerminalModeView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /t to enter a shell command",
            "Press Enter to run the command in your terminal",
            "Press Esc to exit"
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