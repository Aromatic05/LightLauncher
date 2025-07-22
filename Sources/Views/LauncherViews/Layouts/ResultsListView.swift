import SwiftUI

@MainActor
struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // --- 关键改动 ---
                    self.resultsListContent { index in
                        handleItemSelection(at: index)
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
            // --- 关键改动 ---
            if viewModel.shouldHideWindowAfterAction {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }

    @ViewBuilder
    func resultsListContent(handleItemSelection: @escaping (Int) -> Void) -> some View {
        if let controller = viewModel.controllers[viewModel.mode] {
            ForEach(Array(viewModel.displayableItems.enumerated()), id: \ .offset) { index, item in
                controller.makeRowView(
                    for: item,
                    isSelected: index == viewModel.selectedIndex,
                    index: index,
                    handleItemSelection: { _ in handleItemSelection(index) }
                )
                .id(index)
                .onTapGesture { handleItemSelection(index) }
            }
        } else {
            EmptyView()
        }
    }
}
