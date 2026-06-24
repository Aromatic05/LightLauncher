import SwiftUI

struct KillModeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var killController = KillModeController.shared

    var body: some View {
        VStack(spacing: 4) {
            // 标题和强制结束切换按钮
            HStack {
                Text("结束进程")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle(isOn: $killController.forceKillEnabled) {
                    Text(killController.forceKillEnabled ? "强制结束" : "普通结束")
                        .font(.caption)
                        .foregroundColor(killController.forceKillEnabled ? .red : .blue)
                }
                .toggleStyle(SwitchToggleStyle(tint: .red))
                .frame(width: 120)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if viewModel.displayableItems.isEmpty {
                let hasSearchText = !viewModel.searchText.isEmpty
                EmptyStateView(
                    icon: "xmark.circle",
                    iconColor: hasSearchText ? .red.opacity(0.5) : .red.opacity(0.7),
                    title: hasSearchText ? "未找到运行中的应用" : "暂无可关闭的应用",
                    description: hasSearchText
                        ? "请尝试其他搜索关键词"
                        : "输入 \(killController.commandReference()) 后可搜索应用进程",
                    helpTexts: killController.getHelpText()
                )
            } else {
                ResultsListView(viewModel: viewModel)
            }
        }
    }
}
