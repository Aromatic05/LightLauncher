import SwiftUI
import AppKit

// MARK: - Web Mode Views
struct WebCurrentInputView: View {
    let input: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)
            
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("打开: \(input)")
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text("按回车打开网页")
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
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WebModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // 在web模式下首先显示当前输入项
                    let cleanWebText = extractCleanWebText()
                    WebCurrentInputView(
                        input: cleanWebText.isEmpty ? "..." : cleanWebText,
                        isSelected: 0 == viewModel.selectedIndex
                    )
                    .id(0)
                    .onTapGesture {
                        viewModel.selectedIndex = 0
                        if viewModel.executeSelectedAction() {
                            NotificationCenter.default.post(name: .hideWindow, object: nil)
                        }
                    }
                    .focusable(false)
                    
                    // 然后显示浏览器历史项目
                    ForEach(Array(viewModel.browserItems.enumerated()), id: \.element) { index, item in
                        let displayIndex = index + 1 // 因为当前输入项占用了索引0
                        BrowserItemRowView(
                            item: item,
                            isSelected: displayIndex == viewModel.selectedIndex,
                            index: index
                        )
                        .id(displayIndex)
                        .onTapGesture {
                            viewModel.selectedIndex = displayIndex
                            if viewModel.executeSelectedAction() {
                                // 在kill模式下不隐藏窗口
                                if viewModel.mode != .kill {
                                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                                }
                            }
                        }
                        .focusable(false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focusable(false)
            }
            .focusable(false)
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func extractCleanWebText() -> String {
        let prefix = "/w "
        if viewModel.searchText.hasPrefix(prefix) {
            return String(viewModel.searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WebCommandInputView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 模式图标和标题
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Web 浏览")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // 输入提示
            VStack(spacing: 12) {
                Text("输入网址或网站名称，按回车打开")
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
                    "支持完整 URL 或域名",
                    "自动添加 https:// 前缀", 
                    "删除 /w 前缀返回启动模式"
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
        let prefix = "/w "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
