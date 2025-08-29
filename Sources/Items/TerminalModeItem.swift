import AppKit
import Foundation
import SwiftUI

// MARK: - 终端命令历史项
struct TerminalHistoryItem: Codable, Identifiable, Hashable, DisplayableItem {
    let id: UUID
    let command: String
    let timestamp: Date
    var title: String { command }
    var subtitle: String? { "终端命令" }
    var icon: NSImage? { nil }

    @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        if index == 0 {
            return AnyView(TerminalCurrentCommandRowView(command: command, isSelected: isSelected))
        } else {
            return AnyView(
                TerminalHistoryRowView(
                    item: self, isSelected: isSelected, index: index,
                    onDelete: {
                        TerminalModeController.shared.deleteHistoryItem(self)
                    }))
        }
    }

    init(command: String) {
        self.id = UUID()
        self.command = command
        self.timestamp = Date()
    }

    @MainActor
    func executeAction() -> Bool {
        let result = TerminalModeController.shared.terminalExecutor.execute(command: self.command)
        if result {
            TerminalModeController.shared.historyManager.addCommand(self.command)
        }
        return result
    }
}
