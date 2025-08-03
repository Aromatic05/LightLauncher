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
            
            TextField(mode.placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isSearchFieldFocused) // 绑定焦点
            
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
                        .stroke(Color.accentColor.opacity(isSearchFieldFocused ? 0.6 : 0), lineWidth: 2)
                )
        )
        .padding(.horizontal, 24)
        
        // --- 核心逻辑修改 ---
        // 删除了错误的 .onAppear 和 .onChange(of: isSearchFieldFocused)
        
        // 使用新的、正确的逻辑：
        // 当父视图通知我们“窗口已成为关键窗口”时，才请求焦点。
        .onChange(of: isWindowKey) { newIsKey in
            if newIsKey {
                // 使用一小段延迟可以确保窗口的过渡动画完成后再获取焦点，体验更平滑。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
        }
        .onReceive(viewModel.focusSearchField) { _ in
            // 当接收到命令时，执行以下操作：
            
            // a. 设置焦点
            self.isSearchFieldFocused = true
            
            // b. (关键技巧) 为了确保光标在末尾而不是全选，
            //     我们快速地清空并恢复文本。这会重置文本编辑器的状态。
            let currentText = self.searchText
            self.searchText = ""
            DispatchQueue.main.async {
                self.searchText = currentText
            }
        }
    }
}