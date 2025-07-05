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
}
