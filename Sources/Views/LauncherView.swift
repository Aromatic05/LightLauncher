import SwiftUI
import AppKit
import Combine

final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    weak var viewModel: LauncherViewModel?
    private var eventMonitor: Any?
    private var currentMode: LauncherMode = .launch
    
    private init() {}
    
    func updateMode(_ mode: LauncherMode) {
        currentMode = mode
    }
    
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let viewModel = self.viewModel else { return event }
            
            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
            let characters = event.characters
            
            // 预先检查是否是数字键
            let isNumericKey = modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty &&
                              characters != nil &&
                              Int(characters!) != nil &&
                              (1...6).contains(Int(characters!)!)
            
            // 如果是数字键且在web/search/terminal模式下，直接返回事件让它通过
            if isNumericKey && (self.currentMode == .web || self.currentMode == .search || self.currentMode == .terminal) {
                return event
            }
            
            DispatchQueue.main.async {
                switch keyCode {
                case 126: // Up Arrow
                    viewModel.moveSelectionUp()
                case 125: // Down Arrow
                    viewModel.moveSelectionDown()
                case 36, 76: // Enter, Numpad Enter
                    if viewModel.executeSelectedAction() {
                        // 在kill模式下不隐藏窗口
                        if viewModel.mode != .kill {
                            NotificationCenter.default.post(name: .hideWindow, object: nil)
                        }
                    }
                case 53: // Escape
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                default:
                    // Handle numeric shortcuts only if no modifier keys are pressed and not in web mode
                    if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                       let chars = characters,
                       let number = Int(chars),
                       (1...6).contains(number),
                       self.currentMode != .web { // 在web模式下不处理数字快捷键
                        if viewModel.selectAppByNumber(number) {
                            // 在kill模式下不隐藏窗口
                            if viewModel.mode != .kill {
                                NotificationCenter.default.post(name: .hideWindow, object: nil)
                            }
                        }
                    }
                }
            }
            
            switch keyCode {
            case 126, 125, 36, 76, 53: // Navigation keys we want to consume
                return nil
            default:
                // Handle numeric shortcuts - 如果是数字键且不在web模式下，消费事件
                if isNumericKey && self.currentMode != .web {
                    return nil // Consume numeric shortcuts
                }
                return event // Let other keys pass through
            }
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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
            
            // Command Suggestions
            if viewModel.showCommandSuggestions {
                CommandSuggestionsView(commands: viewModel.commandSuggestions)
            }
            
            // Content
            if viewModel.showCommandSuggestions {
                // 当显示命令建议时，不显示其他内容
                Spacer()
            } else {
                switch viewModel.mode {
                case .launch:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            mode: viewModel.mode,
                            hasSearchText: !viewModel.searchText.isEmpty
                        )
                    }
                case .kill:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            mode: viewModel.mode,
                            hasSearchText: !viewModel.searchText.isEmpty
                        )
                    }
                case .web:
                    if viewModel.hasResults || !viewModel.browserItems.isEmpty {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        WebCommandInputView(searchText: viewModel.searchText)
                    }
                case .search:
                    // 搜索模式总是显示搜索历史视图（包含当前输入项）
                    SearchHistoryView(viewModel: viewModel)
                case .terminal:
                    // 终端模式显示输入提示界面
                    TerminalCommandInputView(searchText: viewModel.searchText)
                }
            }
        }
        .frame(width: 700, height: 500)
        .background(
            Color(NSColor.windowBackgroundColor)
        )
        .opacity(0.95)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = nil
        }
        .onChange(of: viewModel.mode) { newMode in
            KeyboardEventHandler.shared.updateMode(newMode)
        }
    }
}

struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        switch viewModel.mode {
        case .launch:
            LaunchModeResultsView(viewModel: viewModel)
        case .kill:
            KillModeResultsView(viewModel: viewModel)
        case .web:
            WebModeResultsView(viewModel: viewModel)
        case .search, .terminal:
            // 这些模式在主视图中处理，不应该到达这里
            EmptyView()
        }
    }
}

struct LaunchModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
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

// Notification names
extension Notification.Name {
    static let hideWindow = Notification.Name("hideWindow")
}
