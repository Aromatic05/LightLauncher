import SwiftUI

// MARK: - Terminal Mode Views
struct TerminalCommandInputView: View {
    // 依赖项与原版完全相同
    @ObservedObject var viewModel = LauncherViewModel.shared
    let searchText: String
    var historyItems: [TerminalHistoryItem]
    var onSelectHistory: ((TerminalHistoryItem) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    TerminalCurrentCommandRowView(
                        command: extractCleanText(),
                        isSelected: viewModel.selectedIndex == 0
                    )
                    .id(0)
                    .onTapGesture {
                        viewModel.selectedIndex = 0
                        onSelectHistory?(
                            TerminalHistoryItem(command: extractCleanText()))
                    }

                    // 历史记录列表
                    ForEach(Array(historyItems.prefix(10).enumerated()), id: \.element) {
                        index, item in
                        let displayIndex = index + 1  // 索引从 1 开始，因为 0 被当前命令占用

                        TerminalHistoryRowView(
                            item: item,
                            isSelected: viewModel.selectedIndex == displayIndex,
                            index: index,
                            onDelete: {
                                // 删除逻辑应由外部实现
                            }
                        )
                        .id(displayIndex)
                        .onTapGesture {
                            viewModel.selectedIndex = displayIndex
                            onSelectHistory?(item)
                        }
                    }

                    if historyItems.isEmpty {
                        Text("暂无历史记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
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

    // 这个辅助函数保持不变
    private func extractCleanText() -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(
                in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
