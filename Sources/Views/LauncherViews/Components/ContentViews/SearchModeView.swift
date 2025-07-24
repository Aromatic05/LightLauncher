import SwiftUI

struct SearchHistoryView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 历史记录标题和清空按钮
            HStack {
                Text("搜索历史")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if !((viewModel.controllers[.search] as? SearchModeController)?.searchHistory
                    .isEmpty ?? true)
                {
                    Button("清空") {
                        (viewModel.controllers[.search] as? SearchModeController)?
                            .clearSearchHistory()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ResultsListView(viewModel: viewModel)
        }
    }
}
