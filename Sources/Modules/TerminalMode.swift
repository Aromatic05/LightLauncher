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

    // MARK: - ModeStateController Protocol Implementation
    let mode: LauncherMode = .terminal
    let prefix: String? = ">"
    let displayName: String = "Terminal"
    let iconName: String = "terminal"
    let placeholder: String = "Enter terminal command to execute..."
    let modeDescription: String? = "Execute shell commands"

    @Published var currentQuery: String = ""

    var displayableItems: [any DisplayableItem] {
        guard !currentQuery.isEmpty else { return [] }
        let tempItem = TerminalHistoryItem(command: currentQuery)
        return [tempItem]
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    func handleInput(arguments: String) {
        self.currentQuery = arguments
        dataDidChange.send()
    }

    func executeAction(at index: Int) -> Bool {
        // 执行命令并保存到历史
        let result = terminalExecutor.execute(command: currentQuery)
        if result {
            historyManager.addCommand(currentQuery)
        }
        return result
    }

    func cleanup() {
        self.currentQuery = ""
        dataDidChange.send()
    }

    func makeContentView() -> AnyView {
        let history = historyManager.getMatchingHistory(for: currentQuery)
        return AnyView(TerminalCommandInputView(searchText: self.currentQuery, historyItems: history, onSelectHistory: { item in
            self.currentQuery = item.command
        }))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /t to enter a shell command",
            "Press Enter to run the command in your terminal",
            "Press Esc to exit"
        ]
    }
}