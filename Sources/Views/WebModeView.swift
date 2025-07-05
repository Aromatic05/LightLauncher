import SwiftUI
import AppKit

// MARK: - Web Mode Views
struct WebModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                        if let browserItem = item as? BrowserItem {
                            BrowserItemRowView(
                                item: browserItem,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    if viewModel.mode != .web {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
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

struct DebugTextView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(4)
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(4)
    }
}
