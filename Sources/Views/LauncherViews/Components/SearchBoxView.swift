import SwiftUI

struct SearchBoxView: View {
    @ObservedObject var viewModel = LauncherViewModel.shared
    @Binding var searchText: String
    @FocusState private var isSearchFieldFocused: Bool
    let mode: LauncherMode

    // 接收来自父视图 LauncherView 的窗口状态
    let isWindowKey: Bool

    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            // 最简单的“不显示超长文本”策略：基于字符数阈值决定是否在输入框中显示文本
            let maxChars = 60
            let displayBinding = Binding<String>(
                get: { self.searchText.count > maxChars ? "" : self.searchText },
                set: { self.searchText = $0 }
            )

            TextField(mode.placeholder, text: displayBinding)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isSearchFieldFocused)  // 绑定焦点

            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.accentColor.opacity(isSearchFieldFocused ? 0.6 : 0), lineWidth: 2)
                )
        )
        .padding(.horizontal, 24)

        .onChange(of: isWindowKey) { newIsKey in
            if newIsKey {
                // 使用一小段延迟可以确保窗口的过渡动画完成后再获取焦点，体验更平滑。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
        }
        .onReceive(viewModel.focusSearchField) { _ in
            self.isSearchFieldFocused = true
            let currentText = self.searchText
            self.searchText = ""
            DispatchQueue.main.async {
                self.searchText = currentText
            }
        }
    }
}
