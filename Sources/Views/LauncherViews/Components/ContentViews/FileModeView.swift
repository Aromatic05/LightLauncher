import SwiftUI

/// 文件浏览器模式视图,有内容时显示文件列表,否则显示空状态。
struct FileModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        if viewModel.displayableItems.isEmpty {
            EmptyStateView(
                icon: "folder.fill",
                iconColor: .blue.opacity(0.8),
                title: "File Browser",
                description: ModeRegistry.shared[FileModeController.self]?.modeDescription,
                helpTexts: ModeRegistry.shared[FileModeController.self]?.getHelpText() ?? []
            )
        } else {
            ResultsListView(viewModel: viewModel)
        }
    }
}
