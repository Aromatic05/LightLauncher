import AppKit
import Combine
import SwiftUI

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            LauncherHeaderView(mode: viewModel.mode)

            // Search Box
            SearchBoxView(
                searchText: $viewModel.searchText,
                mode: viewModel.mode,
                isWindowKey: viewModel.isLauncherWindowKey,
                onClear: {
                    viewModel.clearSearch()
                }
            )

            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 8)

            if viewModel.showCommandSuggestions {
                CommandSuggestionsView(
                    commands: viewModel.commandSuggestions,
                    selectedIndex: $viewModel.selectedIndex,
                    onCommandSelected: { command in
                        viewModel.applySelectedCommand(command)
                    }
                )
            } else if let controller = viewModel.activeController {
                controller.makeContentView()
                    .padding(.bottom, 12)
            } else {
                EmptyView()
            }
        }
        .frame(width: 700, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .opacity(0.95)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}
