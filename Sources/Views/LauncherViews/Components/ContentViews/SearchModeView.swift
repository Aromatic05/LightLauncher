import SwiftUI

struct SearchHistoryView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            HistoryHeader(
                title: "搜索历史",
                canClear: !(ModeRegistry.shared[SearchModeController.self]?.searchHistory.isEmpty ?? true),
                onClear: { ModeRegistry.shared[SearchModeController.self]?.clearSearchHistory() }
            )

            ResultsListView(viewModel: viewModel)
        }
    }
}
