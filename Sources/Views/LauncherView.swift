import SwiftUI
import AppKit
import Combine

final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    weak var viewModel: LauncherViewModel?
    private var eventMonitor: Any?
    
    private init() {}
    
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard let viewModel = viewModel else { return event }
        
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        let characters = event.characters
        
        DispatchQueue.main.async {
            switch keyCode {
            case 126: // Up Arrow
                viewModel.moveSelectionUp()
            case 125: // Down Arrow
                viewModel.moveSelectionDown()
            case 36, 76: // Enter, Numpad Enter
                if viewModel.executeSelectedAction() {
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                }
            case 53: // Escape
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            default:
                // Handle numeric shortcuts only if no modifier keys are pressed
                if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                   let chars = characters,
                   let number = Int(chars),
                   (1...6).contains(number) {
                    if viewModel.selectAppByNumber(number) {
                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                    }
                }
            }
        }
        
        switch keyCode {
        case 126, 125, 36, 76, 53: // Navigation keys we want to consume
            return nil
        default:
            // Handle numeric shortcuts
            if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
               let chars = characters,
               let number = Int(chars),
               (1...6).contains(number) {
                return nil // Consume numeric shortcuts
            }
            return event // Let other keys pass through
        }
    }
}

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
            
            // Content
            if viewModel.hasResults {
                ResultsListView(viewModel: viewModel)
            } else {
                EmptyStateView(
                    mode: viewModel.mode,
                    hasSearchText: !viewModel.searchText.isEmpty
                )
            }
        }
        .frame(width: 700, height: 500)
        .background(
            Color(NSColor.windowBackgroundColor).opacity(0.95)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
    }
}

struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    if viewModel.mode == .launch {
                        ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element) { index, app in
                            AppRowView(
                                app: app,
                                isSelected: index == viewModel.selectedIndex,
                                index: index,
                                mode: .launch
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                                }
                            }
                            .focusable(false)
                        }
                    } else {
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
                                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                                }
                            }
                            .focusable(false)
                        }
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

// Notification names
extension Notification.Name {
    static let hideWindow = Notification.Name("hideWindow")
}
