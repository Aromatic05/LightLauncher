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
                    
                    Text(item.searchEngine.capitalized)
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
    
    private var searchEngineIcon: String {
        switch item.searchEngine.lowercased() {
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
        switch item.searchEngine.lowercased() {
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

struct SearchHistoryView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // 历史记录标题
                    HStack {
                        Text("搜索历史")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !viewModel.searchHistory.isEmpty {
                            Button("清空") {
                                viewModel.clearSearchHistory()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 在搜索模式下首先显示当前输入项
                    let cleanSearchText = extractCleanSearchText()
                    SearchCurrentQueryView(
                        query: cleanSearchText.isEmpty ? "..." : cleanSearchText,
                        isSelected: 0 == viewModel.selectedIndex
                    )
                    .id(0)
                    .onTapGesture {
                        viewModel.selectedIndex = 0
                        if viewModel.executeSelectedAction() {
                            NotificationCenter.default.post(name: .hideWindow, object: nil)
                        }
                    }
                    
                    // 然后显示历史记录列表
                    ForEach(Array(viewModel.searchHistory.prefix(10).enumerated()), id: \.element) { index, item in
                        let displayIndex = index + 1 // 因为当前输入项占用了索引0
                        SearchHistoryRowView(
                            item: item,
                            isSelected: displayIndex == viewModel.selectedIndex,
                            index: index + 1, // 显示序号从1开始
                            onDelete: {
                                viewModel.removeSearchHistoryItem(item)
                            }
                        )
                        .id(displayIndex)
                        .onTapGesture {
                            viewModel.selectedIndex = displayIndex
                            if viewModel.executeSelectedAction() {
                                NotificationCenter.default.post(name: .hideWindow, object: nil)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func extractCleanSearchText() -> String {
        let prefix = "/s "
        if viewModel.searchText.hasPrefix(prefix) {
            return String(viewModel.searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func hasMatchingHistory(_ query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return viewModel.searchHistory.contains { 
            $0.query.lowercased().contains(query.lowercased())
        }
    }
}

struct SearchCommandInputView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 模式图标和标题
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("搜索")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // 输入提示
            VStack(spacing: 12) {
                Text("输入搜索关键词，按回车搜索网页")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if !searchText.isEmpty {
                    let cleanText = extractCleanText()
                    if !cleanText.isEmpty {
                        Text("将执行: \(cleanText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // 帮助文本
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "支持任意关键词搜索",
                    "将使用默认搜索引擎",
                    "删除 /s 前缀返回启动模式"
                ], id: \.self) { text in
                    HStack {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func extractCleanText() -> String {
        let prefix = "/s "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
