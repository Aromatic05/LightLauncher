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
            
            // 检查是否是数字键
            let isNumericKey = self.isNumericShortcut(characters: characters, modifierFlags: modifierFlags)
            
            // 在某些模式下让数字键直接通过
            if isNumericKey && self.shouldPassThroughNumericKey() {
                return event
            }
            
            DispatchQueue.main.async {
                self.handleKeyPress(keyCode: keyCode, characters: characters, viewModel: viewModel)
            }
            
            return self.shouldConsumeEvent(keyCode: keyCode, isNumericKey: isNumericKey) ? nil : event
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
    
    private func shouldPassThroughNumericKey() -> Bool {
        return currentMode == .web || currentMode == .search || currentMode == .terminal
    }
    
    @MainActor
    private func handleKeyPress(keyCode: UInt16, characters: String?, viewModel: LauncherViewModel) {
        switch keyCode {
        case 126: // Up Arrow
            if viewModel.showCommandSuggestions {
                viewModel.moveCommandSuggestionUp()
            } else {
                viewModel.moveSelectionUp()
            }
        case 125: // Down Arrow
            if viewModel.showCommandSuggestions {
                viewModel.moveCommandSuggestionDown()
            } else {
                viewModel.moveSelectionDown()
            }
        case 36, 76: // Enter, Numpad Enter
            handleEnterKey(viewModel: viewModel)
        case 49: // Space
            handleSpaceKey(viewModel: viewModel)
        case 53: // Escape
            NotificationCenter.default.post(name: .hideWindowWithoutActivating, object: nil)
        default:
            handleNumericShortcut(characters: characters, viewModel: viewModel)
        }
    }
    
    @MainActor
    private func handleEnterKey(viewModel: LauncherViewModel) {
        // 如果在命令建议模式下，Enter 键选择当前命令
        if viewModel.showCommandSuggestions {
            // 确保索引有效且有命令建议
            if !viewModel.commandSuggestions.isEmpty && 
               viewModel.selectedIndex >= 0 && 
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                // 成功选择命令，直接返回，不隐藏窗口也不执行其他动作
                return
            }
            // 如果命令建议列表为空或索引无效，隐藏命令建议
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        
        guard viewModel.executeSelectedAction() else { return }
        
        switch viewModel.mode {
        case .kill:
            // Kill 模式不隐藏窗口
            break
        case .file:
            // 文件模式：只有打开文件才关闭窗口
            if let fileItem = viewModel.getFileItem(at: viewModel.selectedIndex), !fileItem.isDirectory {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        case .plugin:
            // 插件模式：根据插件配置决定是否隐藏窗口
            if viewModel.getPluginShouldHideWindowAfterAction() {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        default:
            NotificationCenter.default.post(name: .hideWindow, object: nil)
        }
    }
    
    @MainActor
    private func handleSpaceKey(viewModel: LauncherViewModel) {
        // 如果在命令建议模式下，空格键选择当前命令
        if viewModel.showCommandSuggestions {
            // 确保索引有效且有命令建议
            if !viewModel.commandSuggestions.isEmpty && 
               viewModel.selectedIndex >= 0 && 
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                // 成功选择命令，直接返回
                return
            }
            // 如果命令建议列表为空或索引无效，隐藏命令建议
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        
        // 其他模式的空格键处理
        if currentMode == .file {
            viewModel.openSelectedFileInFinder()
        }
    }
    
    @MainActor
    private func handleNumericShortcut(characters: String?, viewModel: LauncherViewModel) {
        guard let chars = characters,
              let number = Int(chars),
              (1...6).contains(number),
              !shouldPassThroughNumericKey() else {
            return
        }
        
        if viewModel.selectAppByNumber(number) {
            // 根据模式决定是否隐藏窗口
            switch viewModel.mode {
            case .kill:
                // kill模式下不隐藏窗口
                break
            case .plugin:
                // 插件模式：根据插件配置决定是否隐藏窗口
                if viewModel.getPluginShouldHideWindowAfterAction() {
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                }
            default:
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }
    
    private func shouldConsumeEvent(keyCode: UInt16, isNumericKey: Bool) -> Bool {
        switch keyCode {
        case 126, 125, 36, 76, 53: // Navigation keys and Escape
            return true
        case 49: // Space key - consume in file mode
            return currentMode == .file
        default:
            // Consume numeric shortcuts when not in passthrough modes
            return isNumericKey && !shouldPassThroughNumericKey()
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
                CommandSuggestionsView(
                    commands: viewModel.commandSuggestions,
                    selectedIndex: $viewModel.selectedIndex,
                    onCommandSelected: { command in
                        viewModel.applySelectedCommand(command)
                    }
                )
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
                case .file:
                    // 文件模式显示文件浏览器
                    if viewModel.showStartPaths {
                        // 显示起始路径选择
                        if !viewModel.fileBrowserStartPaths.isEmpty {
                            ResultsListView(viewModel: viewModel)
                        } else {
                            FileCommandInputView(currentPath: viewModel.currentPath)
                        }
                    } else {
                        // 显示文件列表
                        if !viewModel.currentFiles.isEmpty {
                            ResultsListView(viewModel: viewModel)
                        } else {
                            FileCommandInputView(currentPath: viewModel.currentPath)
                        }
                    }
                case .clip:
                    if !viewModel.currentClipItems.isEmpty {
                        ClipModeResultsView(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            mode: viewModel.mode,
                            hasSearchText: !viewModel.searchText.isEmpty
                        )
                    }
                case .plugin:
                    // 插件模式显示专用的插件视图
                    PluginModeView(viewModel: viewModel)
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
        // 使用统一的结果视图，避免重复的 switch case
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    switch viewModel.mode {
                    case .launch:
                        ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element) { index, app in
                            AppRowView(
                                app: app,
                                isSelected: index == viewModel.selectedIndex,
                                index: index,
                                mode: .launch
                            )
                            .id(index)
                            .onTapGesture { handleItemSelection(at: index) }
                        }
                    case .kill:
                        ForEach(Array(viewModel.runningApps.enumerated()), id: \.element) { index, app in
                            RunningAppRowView(
                                app: app,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture { handleItemSelection(at: index) }
                        }
                    case .web:
                        ForEach(Array(viewModel.browserItems.enumerated()), id: \.offset) { index, item in
                            BrowserItemRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture { handleItemSelection(at: index) }
                        }
                    case .file:
                        if viewModel.showStartPaths {
                            ForEach(Array(viewModel.fileBrowserStartPaths.enumerated()), id: \.offset) { index, startPath in
                                StartPathRowView(
                                    startPath: startPath,
                                    isSelected: index == viewModel.selectedIndex,
                                    index: index
                                )
                                .id(index)
                                .onTapGesture { handleItemSelection(at: index) }
                            }
                        } else {
                            ForEach(Array(viewModel.currentFiles.enumerated()), id: \.offset) { index, item in
                                FileRowView(
                                    file: item,
                                    isSelected: index == viewModel.selectedIndex,
                                    index: index
                                )
                                .id(index)
                                .onTapGesture { handleItemSelection(at: index) }
                            }
                        }
                    case .clip:
                        ForEach(Array(viewModel.currentClipItems.enumerated()), id: \ .offset) { index, item in
                            ClipItemRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture { handleItemSelection(at: index) }
                        }
                    case .search, .terminal, .plugin:
                        EmptyView()
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
            // 根据模式决定是否隐藏窗口
            if shouldHideWindowAfterAction() {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }
    
    private func shouldHideWindowAfterAction() -> Bool {
        switch viewModel.mode {
        case .launch:
            return true
        case .kill :
            return false // kill 模式不隐藏窗口
        case .web:
            return true
        case .file:
            // 文件模式：只有打开文件才关闭窗口，进入目录不关闭
            if let fileItem = viewModel.getFileItem(at: viewModel.selectedIndex) {
                return !fileItem.isDirectory
            }
            return true
        case .search, .terminal, .clip:
            return true
        case .plugin:
            // 插件模式：使用插件设置的窗口隐藏行为
            return viewModel.getPluginShouldHideWindowAfterAction()
        }
    }
}
