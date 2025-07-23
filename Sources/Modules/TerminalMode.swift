import SwiftUI
import Combine

@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    // 终端命令历史管理器
    private let historyManager = TerminalHistoryManager.shared
    static let shared = TerminalModeController()
    private override init() {}

    // MARK: - Dependencies
    /// 唯一的依赖项：终端执行服务
    private let terminalExecutor = TerminalExecutorService.shared

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

    func executeAction(at index: Int) -> Bool {
        // index == 0 执行当前命令，否则执行历史项
        let items = displayableItems
        guard index < items.count else { return false }
        let commandToExecute: String
        if index == 0 {
            commandToExecute = currentQuery
        } else if let historyItem = items[index] as? TerminalHistoryItem {
            commandToExecute = historyItem.command
        } else {
            return false
        }

        let result = terminalExecutor.execute(command: commandToExecute)
        if result {
            historyManager.addCommand(commandToExecute)
        }
        return result
    }

    func cleanup() {
        self.currentQuery = ""
        dataDidChange.send()
    }

    func makeContentView() -> AnyView {
        return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /t to enter a shell command",
            "Press Enter to run the command in your terminal",
            "Press Esc to exit"
        ]
    }
}