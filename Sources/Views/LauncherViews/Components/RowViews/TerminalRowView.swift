import AppKit
import SwiftUI

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
        } else if calendar.isDate(
            date,
            inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
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
                .stroke(
                    isSelected ? Color.accentColor : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
