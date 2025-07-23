import SwiftUI
import AppKit

// MARK: - 终端命令历史行视图
struct TerminalHistoryRowView: View {
    let item: TerminalHistoryItem
    let isSelected: Bool
    let index: Int
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 序号
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            // 图标
            Image(systemName: "terminal")
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.command)
                    .font(.system(size: 14))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(formatTime(item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 删除按钮
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Terminal Mode Views
struct TerminalCommandInputView: View {
    let searchText: String
    var historyItems: [TerminalHistoryItem] = []
    var onSelectHistory: ((TerminalHistoryItem) -> Void)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // 当前输入命令作为第一个item
                    TerminalCurrentCommandRowView(
                        command: extractCleanText(),
                        isSelected: 0 == 0 // 选中逻辑后续可由外部传入
                    )
                    .id(0)
                    .onTapGesture {
                        onSelectHistory?(TerminalHistoryItem(command: extractCleanText()))
                    }

                    // 历史记录列表
                    ForEach(Array(historyItems.prefix(10).enumerated()), id: \.element) { index, item in
                        let displayIndex = index + 1 // 当前输入占用0
                        TerminalHistoryRowView(
                            item: item,
                            isSelected: false, // 选中逻辑后续可由外部传入
                            index: displayIndex,
                            onDelete: {
                                // 这里建议通过外部回调实现删除功能
                            }
                        )
                        .id(displayIndex)
                        .onTapGesture {
                            onSelectHistory?(item)
                        }
                    }

                    if historyItems.isEmpty {
                        Text("暂无历史记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            // 可支持选中项自动滚动
            // .onChange(of: selectedIndex) { newIndex in ... }
        }
    }
// 当前命令的行视图
struct TerminalCurrentCommandRowView: View {
    let command: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)

            Image(systemName: "terminal")
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.isEmpty ? "..." : command)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text("按回车执行命令")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "return")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

    private func extractCleanText() -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
