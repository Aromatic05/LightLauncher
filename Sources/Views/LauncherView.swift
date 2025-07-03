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
            let isNumericKey = self.isNumericShortcut(characters: characters, modifierFlags: modifierFlags)
            // 事件消费与透传判断全部放到主线程
            var shouldPassThrough = false
            // var shouldConsume = false
            Task { @MainActor in
                shouldPassThrough = viewModel.facade.shouldPassThroughNumericKey() && isNumericKey
                // shouldConsume = viewModel.facade.shouldConsumeEvent(keyCode: keyCode, isNumericKey: isNumericKey)
                if !shouldPassThrough {
                    viewModel.facade.handleKeyPress(keyCode: keyCode, characters: characters)
                }
            }
            // 这里不能同步返回 nil 只能保守返回 event，实际消费交由主线程处理
            if isNumericKey {
                return shouldPassThrough ? event : nil
            }
            return event
        }
    }
    
    private func isNumericShortcut(characters: String?, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
              let chars = characters,
              let number = Int(chars),
              (1...6).contains(number) else {
            return false
        }
        return true
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
                CommandSuggestionsView(
                    commands: viewModel.commandSuggestions,
                    selectedIndex: $viewModel.selectedIndex,
                    onCommandSelected: { command in
                        viewModel.applySelectedCommand(command)
                    }
                )
            }
            // --- 关键改动 ---
            // 用一行代码替换掉原来整个 if/switch 逻辑块
            viewModel.facade.contentView()
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // --- 关键改动 ---
                    viewModel.facade.resultsListContent { index in
                        handleItemSelection(at: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func handleItemSelection(at index: Int) {
        viewModel.selectedIndex = index
        if viewModel.executeSelectedAction() {
            // --- 关键改动 ---
            if viewModel.facade.shouldHideWindowAfterAction() {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }
}
