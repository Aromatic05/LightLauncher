import SwiftUI

struct TerminalHistoryRowView: View {
    let item: TerminalHistoryItem
    let isSelected: Bool
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        HistoryRow(
            index: index,
            iconName: "terminal",
            iconColor: .orange,
            title: item.command,
            timestamp: item.timestamp,
            category: nil,
            isSelected: isSelected,
            onDelete: onDelete
        )
    }
}

struct TerminalCurrentCommandRowView: View {
    let command: String
    let isSelected: Bool

    var body: some View {
        CurrentQueryRow(
            iconName: "terminal",
            iconColor: .orange,
            title: command.isEmpty ? "..." : command,
            hintText: "按 Enter 在终端中执行",
            isSelected: isSelected,
            normalBorderColor: .orange,
            normalFillColor: .orange.opacity(0.05)
        )
    }
}
