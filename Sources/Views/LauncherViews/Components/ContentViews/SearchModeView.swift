import SwiftUI

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
                        if !((viewModel.controllers[.search] as? SearchModeController)?.searchHistory.isEmpty ?? true) {
                            Button("清空") {
                                (viewModel.controllers[.search] as? SearchModeController)?.clearSearchHistory()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 在搜索模式下首先显示当前输入项
                    let cleanSearchText = (viewModel.controllers[.search] as? SearchModeController)?.extractCleanSearchText(from: viewModel.searchText) ?? ""
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
                    ForEach(Array(((viewModel.controllers[.search] as? SearchModeController)?.searchHistory.prefix(10) ?? []).enumerated()), id: \.element) { index, item in
                        let displayIndex = index + 1 // 因为当前输入项占用了索引0
                        SearchHistoryRowView(
                            item: item,
                            isSelected: displayIndex == viewModel.selectedIndex,
                            index: index + 1, // 显示序号从1开始
                            onDelete: {
                                (viewModel.controllers[.search] as? SearchModeController)?.removeSearchHistoryItem(item)
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
}
