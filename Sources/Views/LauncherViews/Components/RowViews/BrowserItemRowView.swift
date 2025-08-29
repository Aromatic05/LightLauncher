import SwiftUI

// MARK: - 浏览器项目行视图
struct BrowserItemRowView: View {
    let item: BrowserItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: item.iconName ?? defaultIconName(for: item.type))
                .font(.title3)
                .foregroundColor(iconColor(for: item))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                // 标题
                Text(item.title)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 副标题/URL/附加信息
                HStack(spacing: 8) {
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(item.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    // 类型标签和来源
                    if let actionHint = item.actionHint {
                        Text(actionHint)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        HStack(spacing: 4) {
                            Text(item.source.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(browserSourceColor(item.source).opacity(0.3))
                                .foregroundColor(browserSourceColor(item.source))
                                .cornerRadius(3)
                            if item.type == .history {
                                if item.visitCount > 1 {
                                    Text("访问 \(item.visitCount) 次")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                if let lastVisited = item.lastVisited {
                                    Text(formatRelativeDate(lastVisited))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else if item.type == .bookmark {
                                Text("书签")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            // 序号
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 2_592_000 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    private func browserSourceColor(_ source: BrowserType) -> Color {
        switch source {
        case .safari:
            return .blue
        case .chrome:
            return .green
        case .edge:
            return .teal
        case .firefox:
            return .orange
        case .arc:
            return .purple
        }
    }

    private func defaultIconName(for type: BrowserItemType) -> String {
        switch type {
        case .bookmark:
            return "bookmark.fill"
        case .history:
            return "clock"
        case .input:
            return "globe"
        }
    }
    private func iconColor(for item: BrowserItem) -> Color {
        switch item.type {
        case .bookmark:
            return .orange
        case .history:
            return .blue
        case .input:
            return .green
        }
    }
}
