import SwiftUI
import AppKit
import Combine

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
            } else {
                EmptyView()
            }
        }
        .frame(width: 700, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .opacity(0.95)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            KeyboardEventHandler.shared.stopMonitoring()
        }
        // .onChange(of: viewModel.mode) { newMode in
        //     KeyboardEventHandler.shared.startMonitoring()
        // }
    }
}