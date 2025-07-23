import SwiftUI
import AppKit

// MARK: - Web Mode Views

/// 负责显示 Web 模式下的搜索结果列表
struct WebModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // 【已修复】ForEach 的 id 使用 item.id 来保证唯一性和稳定性
                    ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                        // 确保 item 是我们期望的类型
                        if let browserItem = item as? BrowserItem {
                            // 【已修复】传递 BrowserItemRowView 需要的所有参数
                            AnyView(
                                BrowserItemRowView(
                                    item: browserItem,
                                    isSelected: index == viewModel.selectedIndex,
                                    index: index // 传递正确的索引
                                )
                                .onTapGesture {
                                    // 【已修复】单击只负责更新选择的索引，不立即执行
                                    viewModel.selectedIndex = index
                                }
                            )
                            .id(index) // ScrollViewReader 依赖这个 id
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                if newIndex < viewModel.displayableItems.count {
                    let selectedItemID = viewModel.displayableItems[newIndex].id
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(selectedItemID, anchor: .center)
                    }
                }
            }
        }
    }
}

/// 当没有搜索结果时，显示的特定输入视图
struct WebCommandInputView: View {
    // 【已修复】接收由 Controller 处理好的、纯净的当前查询
    let currentQuery: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Open Web Page")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            VStack(spacing: 12) {
                Text("Enter a URL or search term")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if !currentQuery.isEmpty {
                    Text("Will open or search for: \(currentQuery)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "Full URLs and domain names are supported.",
                    "https:// prefix is added automatically.",
                    "Press Enter to open in your browser."
                ], id: \.self) { text in
                    HStack {
                        Circle().fill(Color.secondary).frame(width: 4, height: 4)
                        Text(text).font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}