import SwiftUI

struct TerminalModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 历史记录标题和清空按钮
            HStack {
                Text("终端命令历史")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if let terminalController = ModeRegistry.shared[TerminalModeController.self] {
                    Button("清空") {
                        terminalController.clearHistory()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

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
