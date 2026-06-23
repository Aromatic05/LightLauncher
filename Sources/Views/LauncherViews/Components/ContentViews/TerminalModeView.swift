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
                if let terminalController = viewModel.controllers[.terminal]
                    as? TerminalModeController
                {
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

            ResultsListView(viewModel: viewModel)
        }
    }
}
