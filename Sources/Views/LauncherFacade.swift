import SwiftUI

// 这个类不持有任何状态，它只是一个逻辑处理器。
// 它弱引用 ViewModel 来读取状态和调用方法。
final class LauncherFacade {
    // 使用 weak 避免循环引用
    private weak var viewModel: LauncherViewModel?

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    // 如果 viewModel 可能被释放，提供一个 guard let 封装
    private func withViewModel<T>(_ action: (LauncherViewModel) -> T, default: T) -> T {
        guard let viewModel = viewModel else { return `default` }
        return action(viewModel)
    }
}

@MainActor
extension LauncherFacade {
    // 视图主内容区逻辑
    @ViewBuilder
    func contentView() -> some View {
        if let viewModel = viewModel {
            if viewModel.showCommandSuggestions {
                Spacer()
            } else {
                switch viewModel.mode {
                case .launch:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(mode: viewModel.mode, hasSearchText: !viewModel.searchText.isEmpty)
                    }
                case .kill:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(mode: viewModel.mode, hasSearchText: !viewModel.searchText.isEmpty)
                    }
                case .web:
                    if viewModel.hasResults || !viewModel.displayableItems.isEmpty {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        WebCommandInputView(searchText: viewModel.searchText)
                    }
                case .search:
                    SearchHistoryView(viewModel: viewModel)
                case .terminal:
                    TerminalCommandInputView(searchText: viewModel.searchText)
                case .file:
                    if viewModel.showStartPaths {
                        if !viewModel.fileBrowserStartPaths.isEmpty {
                            ResultsListView(viewModel: viewModel)
                        } else {
                            FileCommandInputView(currentPath: viewModel.currentPath)
                        }
                    } else {
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
                        EmptyStateView(mode: viewModel.mode, hasSearchText: !viewModel.searchText.isEmpty)
                    }
                case .plugin:
                    PluginModeView(viewModel: viewModel)
                }
            }
        } else {
            EmptyView()
        }
    }

    // 结果列表内容逻辑
    @ViewBuilder
    func resultsListContent(handleItemSelection: @escaping (Int) -> Void) -> some View {
        if let viewModel = viewModel {
            switch viewModel.mode {
            case .launch:
                ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element) { index, app in
                    AppRowView(app: app, isSelected: index == viewModel.selectedIndex, index: index, mode: .launch)
                        .id(index)
                        .onTapGesture { handleItemSelection(index) }
                }
            case .kill:
                ForEach(Array(viewModel.runningApps.enumerated()), id: \.element) { index, app in
                    RunningAppRowView(app: app, isSelected: index == viewModel.selectedIndex, index: index)
                        .id(index)
                        .onTapGesture { handleItemSelection(index) }
                }
            case .web:
                ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                    if let browserItem = item as? BrowserItem {
                        BrowserItemRowView(item: browserItem, isSelected: index == viewModel.selectedIndex, index: index)
                            .id(index)
                            .onTapGesture { handleItemSelection(index) }
                    }
                }
            case .file:
                if viewModel.showStartPaths {
                    ForEach(Array(viewModel.fileBrowserStartPaths.enumerated()), id: \.offset) { index, startPath in
                        StartPathRowView(startPath: startPath, isSelected: index == viewModel.selectedIndex, index: index)
                            .id(index)
                            .onTapGesture { handleItemSelection(index) }
                    }
                } else {
                    ForEach(Array(viewModel.currentFiles.enumerated()), id: \.offset) { index, item in
                        FileRowView(file: item, isSelected: index == viewModel.selectedIndex, index: index)
                            .id(index)
                            .onTapGesture { handleItemSelection(index) }
                    }
                }
            case .clip:
                ForEach(Array(viewModel.currentClipItems.enumerated()), id: \.offset) { index, item in
                    ClipItemRowView(item: item, isSelected: index == viewModel.selectedIndex, index: index)
                        .id(index)
                        .onTapGesture { handleItemSelection(index) }
                }
            case .search, .terminal, .plugin:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // 是否应隐藏窗口
    func shouldHideWindowAfterAction() -> Bool {
        withViewModel({ viewModel in
            switch viewModel.mode {
            case .launch:
                return true
            case .kill:
                return false
            case .web:
                return true
            case .file:
                if let fileItem = viewModel.getFileItem(at: viewModel.selectedIndex) {
                    return !fileItem.isDirectory
                }
                return true
            case .search, .terminal, .clip:
                return true
            case .plugin:
                // if let pluginController = viewModel.controllers[.plugin] as? PluginModeController {
                //     return pluginController.getPluginShouldHideWindowAfterAction()
                // }
                return false
            }
        }, default: false)
    }

    // 是否允许数字键透传
    func shouldPassThroughNumericKey() -> Bool {
        return withViewModel({ viewModel in
            let mode = viewModel.mode
            return mode == .web || mode == .search || mode == .terminal
        }, default: false)
    }

    // 键盘事件处理统一入口
    @MainActor
    func handleKeyPress(keyCode: UInt16, characters: String?) {
        guard let viewModel = viewModel else { return }
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
            handleEnterKey()
        case 49: // Space
            handleSpaceKey()
        case 53: // Escape
            NotificationCenter.default.post(name: .hideWindowWithoutActivating, object: nil)
        default:
            handleNumericShortcut(characters: characters)
        }
    }

    @MainActor
    func handleEnterKey() {
        guard let viewModel = viewModel else { return }
        if viewModel.showCommandSuggestions {
            if !viewModel.commandSuggestions.isEmpty &&
               viewModel.selectedIndex >= 0 &&
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                return
            }
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        guard viewModel.executeSelectedAction() else { return }
        switch viewModel.mode {
        case .kill:
            break
        case .file:
            if let fileItem = viewModel.getFileItem(at: viewModel.selectedIndex), !fileItem.isDirectory {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        case .plugin:
            break
            // if let pluginController = viewModel.controllers[.plugin] as? PluginModeController,
            //    pluginController.getPluginShouldHideWindowAfterAction() {
            //     NotificationCenter.default.post(name: .hideWindow, object: nil)
            // }
        default:
            NotificationCenter.default.post(name: .hideWindow, object: nil)
        }
    }

    @MainActor
    func handleSpaceKey() {
        guard let viewModel = viewModel else { return }
        if viewModel.showCommandSuggestions {
            if !viewModel.commandSuggestions.isEmpty &&
               viewModel.selectedIndex >= 0 &&
               viewModel.selectedIndex < viewModel.commandSuggestions.count {
                let selectedCommand = viewModel.commandSuggestions[viewModel.selectedIndex]
                viewModel.applySelectedCommand(selectedCommand)
                return
            }
            viewModel.showCommandSuggestions = false
            viewModel.commandSuggestions = []
            return
        }
        if viewModel.mode == .file,
           let fileController = viewModel.controllers[.file] as? FileModeController,
           !viewModel.showStartPaths,
           let fileItem = viewModel.getFileItem(at: viewModel.selectedIndex) {
            fileController.openInFinder(fileItem.url)
        }
    }

    @MainActor
    func handleNumericShortcut(characters: String?) {
        guard let viewModel = viewModel else { return }
        guard let chars = characters,
              let number = Int(chars),
              (1...6).contains(number),
              !shouldPassThroughNumericKey() else {
            return
        }
        if viewModel.selectAppByNumber(number) {
            switch viewModel.mode {
            case .kill:
                break
            case .plugin:
                break
                // if let pluginController = viewModel.controllers[.plugin] as? PluginModeController,
                //    pluginController.getPluginShouldHideWindowAfterAction() {
                //     NotificationCenter.default.post(name: .hideWindow, object: nil)
                // }
            default:
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }

    func shouldConsumeEvent(keyCode: UInt16, isNumericKey: Bool) -> Bool {
        return withViewModel({ viewModel in
            switch keyCode {
            case 126, 125, 36, 76, 53:
                return true
            case 49:
                return viewModel.mode == .file
            default:
                return isNumericKey && !shouldPassThroughNumericKey()
            }
        }, default: false)
    }
}
