import SwiftUI
import AppKit

// MARK: - Kill Mode Views
struct KillModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.runningApps.enumerated()), id: \.element) { index, app in
                        RunningAppRowView(
                            app: app,
                            isSelected: index == viewModel.selectedIndex,
                            index: index
                        )
                        .id(index)
                        .onTapGesture {
                            viewModel.selectedIndex = index
                            if viewModel.executeSelectedAction() {
                                // 在kill模式下不隐藏窗口
                                if viewModel.mode != .kill {
                                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                                }
                            }
                        }
                        .focusable(false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focusable(false)
            }
            .focusable(false)
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
