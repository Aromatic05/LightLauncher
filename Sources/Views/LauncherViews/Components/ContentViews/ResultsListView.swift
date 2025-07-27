import SwiftUI

/// 默认视图，用于显示搜索结果列表，无额外组件，可以按需求进行修改
@MainActor
struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    var onSelectionChanged: ((Int) -> Void)? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.displayableItems.enumerated()), id: \ .offset) { index, item in
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
                proxy.scrollTo(newIndex)
                onSelectionChanged?(newIndex)
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
