import SwiftUI
import Combine

struct CurrentCommandItem: DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(TerminalCommandInputView(searchText: title))
    }
    let id = UUID()
    let title: String
    var subtitle: String? { "将要执行的命令: \(title)" }
    var icon: NSImage? { nil }
}

@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
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
        return currentQuery.isEmpty ? [] : [CurrentCommandItem(title: currentQuery)]
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    func handleInput(arguments: String) {
        self.currentQuery = arguments
    }

    func executeAction(at index: Int) -> Bool {
        // 职责极度简化：直接调用服务来执行命令
        return terminalExecutor.execute(command: currentQuery)
    }

    func cleanup() {
        self.currentQuery = ""
    }

    func makeContentView() -> AnyView {
        return AnyView(TerminalCommandInputView(searchText: self.currentQuery))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /t to enter a shell command",
            "Press Enter to run the command in your terminal",
            "Press Esc to exit"
        ]
    }
}