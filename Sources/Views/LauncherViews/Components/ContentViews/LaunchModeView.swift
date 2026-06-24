import SwiftUI

/// 默认启动模式视图,展示应用/系统命令/设置项搜索结果,无搜索结果时显示空状态。
struct LaunchModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        if viewModel.displayableItems.isEmpty {
            let hasSearchText = !viewModel.searchText.isEmpty
            EmptyStateView(
                icon: hasSearchText ? "magnifyingglass" : "app.badge",
                iconColor: hasSearchText ? .secondary.opacity(0.5) : .accentColor.opacity(0.7),
                title: hasSearchText ? "未找到应用" : "开始输入以搜索应用",
                description: hasSearchText ? "请尝试其他搜索关键词" : nil,
                helpTexts: ModeRegistry.shared[LaunchModeController.self]?.getHelpText() ?? []
            )
        } else {
            ResultsListView(viewModel: viewModel)
        }
    }
}
