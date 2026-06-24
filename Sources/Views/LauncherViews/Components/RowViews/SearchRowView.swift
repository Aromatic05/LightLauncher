import SwiftUI

struct SearchCurrentQueryView: View {
    let query: String
    let isSelected: Bool

    var body: some View {
        CurrentQueryRow(
            iconName: "magnifyingglass",
            iconColor: .blue,
            title: "搜索: \(query)",
            hintText: "按回车执行搜索",
            isSelected: isSelected,
            normalBorderColor: .blue,
            normalFillColor: .blue.opacity(0.05)
        )
    }
}

struct SearchHistoryRowView: View {
    let item: SearchHistoryItem
    let isSelected: Bool
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        HistoryRow(
            index: index,
            iconName: searchEngineIcon,
            iconColor: searchEngineColor,
            title: item.query,
            timestamp: item.timestamp,
            category: item.category.capitalized,
            isSelected: isSelected,
            onDelete: onDelete
        )
    }

    private var searchEngineIcon: String {
        switch item.category.lowercased() {
        case "google": return "globe"
        case "baidu": return "globe.asia.australia"
        case "bing": return "globe.americas"
        default: return "magnifyingglass"
        }
    }

    private var searchEngineColor: Color {
        switch item.category.lowercased() {
        case "google": return .blue
        case "baidu": return .red
        case "bing": return .green
        default: return .secondary
        }
    }
}
