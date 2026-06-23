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

            ResultsListView(viewModel: viewModel)
        }
    }
}
