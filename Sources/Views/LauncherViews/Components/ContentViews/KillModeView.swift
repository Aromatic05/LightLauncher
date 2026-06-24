import SwiftUI

struct KillModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 标题和强制结束切换按钮
            HStack {
                Text("结束进程")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                forceKillToggle
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
                        : "输入 \(ModeRegistry.shared[KillModeController.self]?.commandReference() ?? "/k") 后可搜索应用进程",
                    helpTexts: ModeRegistry.shared[KillModeController.self]?.getHelpText() ?? []
                )
            } else {
                ResultsListView(viewModel: viewModel)
            }
        }
    }

    /// Toggle 的 Binding 通过 get/set 闭包直接读写 controller,
    /// 避免为这一个 binding 引入 @ObservedObject 走 controller 自己的 objectWillChange 路径。
    /// controller 自身的 `forceKillEnabled` setter 会发 `dataDidChange`,VM 的 `viewSyncToken` 随之自增,
    /// 本 view body 在下一次重算时会读到最新值,Toggle UI 自动同步。
    @ViewBuilder
    private var forceKillToggle: some View {
        let killController = ModeRegistry.shared[KillModeController.self]
        if let killController = killController {
            let isOn = killController.forceKillEnabled
            Toggle(isOn: Binding(
                get: { killController.forceKillEnabled },
                set: { killController.forceKillEnabled = $0 }
            )) {
                Text(isOn ? "强制结束" : "普通结束")
                    .font(.caption)
                    .foregroundColor(isOn ? .red : .blue)
            }
            .toggleStyle(SwitchToggleStyle(tint: .red))
            .frame(width: 120)
        }
    }
}
