import SwiftUI

struct ClipModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 4) {
            // 历史记录标题和清空按钮
            HStack {
                Text("剪切板历史")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if let clipController = viewModel.controllers[.clip] as? ClipModeController,
                   !ClipboardManager.shared.getHistory().isEmpty {
                    Button("清空") {
                        ClipboardManager.shared.clearHistory()
                        clipController.handleInput(arguments: "")
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
