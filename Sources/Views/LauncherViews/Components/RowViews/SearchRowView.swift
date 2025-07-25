import SwiftUI
import AppKit

// MARK: - Search Mode Views
struct SearchCurrentQueryView: View {
    let query: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("搜索: \(query)")
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text("按回车执行搜索")
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
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SearchHistoryRowView: View {
    let item: SearchHistoryItem
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
            
            // 搜索引擎图标
            Image(systemName: searchEngineIcon)
                .font(.system(size: 16))
                .foregroundColor(searchEngineColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                // 搜索查询
                Text(item.query)
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                // 时间和搜索引擎
                HStack(spacing: 8) {
                    Text(formatTime(item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.category.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 删除按钮
            if isHovered {
                Button(action: {
                    onDelete()
                }) {
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
    
    private var searchEngineIcon: String {
        switch item.category.lowercased() {
        case "google":
            return "globe"
        case "baidu":
            return "globe.asia.australia"
        case "bing":
            return "globe.americas"
        default:
            return "magnifyingglass"
        }
    }
    
    private var searchEngineColor: Color {
        switch item.category.lowercased() {
        case "google":
            return .blue
        case "baidu":
            return .red
        case "bing":
            return .green
        default:
            return .secondary
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