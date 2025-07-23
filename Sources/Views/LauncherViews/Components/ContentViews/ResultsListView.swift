import SwiftUI

@MainActor
struct ResultsListView: View {
    // 依然观察 ViewModel 来获取 displayableItems 和 selectedIndex
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // --- 终极简化 ---
                    // 直接遍历 items，让 item 自己创建视图
                    ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                        item.makeRowView(isSelected: index == viewModel.selectedIndex, index: index)
                            .id(index)
                            .onTapGesture {
                                handleItemSelection(at: index)
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
    
    private func handleItemSelection(at index: Int) {
        viewModel.selectedIndex = index
        if viewModel.executeSelectedAction() {
            if viewModel.shouldHideWindowAfterAction {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }
}
