import SwiftUI

struct TerminalModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            HistoryHeader(
                title: "终端命令历史",
                canClear: ModeRegistry.shared[TerminalModeController.self] != nil,
                onClear: { ModeRegistry.shared[TerminalModeController.self]?.clearHistory() }
            )

            if viewModel.displayableItems.isEmpty {
                let hasSearchText = !viewModel.searchText.isEmpty
                EmptyStateView(
                    icon: "terminal",
                    iconColor: .orange.opacity(hasSearchText ? 0.5 : 0.7),
                    title: hasSearchText ? "未找到匹配的命令" : "暂无终端命令历史",
                    description: hasSearchText ? "请尝试其他搜索关键词" : nil,
                    helpTexts: ModeRegistry.shared[TerminalModeController.self]?.getHelpText() ?? []
                )
            } else {
                ResultsListView(viewModel: viewModel)
            }
        }
    }
}
