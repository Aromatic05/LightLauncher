import AppKit
import SwiftUI

enum DateFormatting {
    static func historyItemTime(_ date: Date) -> String {
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

    static func relativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else if interval < 2_592_000 {
            return "\(Int(interval / 86400))天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct NumberedIconRow<Trailing: View>: View {
    let index: Int
    let icon: NSImage?
    let fallbackIconName: String
    let fallbackGradient: [Color]
    let title: String
    let subtitle: String?
    let subtitleColor: Color
    let isSelected: Bool
    let selectedGradient: [Color]
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 24, height: 24)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : subtitleColor)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: selectedGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: fallbackGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: fallbackIconName)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                )
        }
    }
}

struct HistoryRow: View {
    let index: Int
    let iconName: String
    let iconColor: Color
    let title: String
    let timestamp: Date
    let category: String?
    let isSelected: Bool
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(DateFormatting.historyItemTime(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let category = category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

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
}

struct CurrentQueryRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let hintText: String
    let isSelected: Bool
    let normalBorderColor: Color
    let normalFillColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)

            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text(hintText)
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
                .fill(isSelected ? Color.accentColor.opacity(0.1) : normalFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : normalBorderColor.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

struct HistoryHeader: View {
    let title: String
    let canClear: Bool
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            if canClear {
                Button("清空", action: onClear)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
