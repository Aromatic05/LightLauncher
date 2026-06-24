import SwiftUI

/// 把 `LauncherMode` 路由到具体的模式视图。
/// 让 SwiftUI 持有具体 view 类型(无 AnyView),让 Controller 不再 import SwiftUI 就能渲染。
struct ModeContentView: View {
    let mode: LauncherMode
    let viewModel: LauncherViewModel

    var body: some View {
        switch mode {
        case .launch:    LaunchModeView(viewModel: viewModel)
        case .kill:      KillModeView(viewModel: viewModel)
        case .file:      FileModeView(viewModel: viewModel)
        case .search:    SearchHistoryView(viewModel: viewModel)
        case .web:       ResultsListView(viewModel: viewModel)
        case .terminal:  TerminalModeView(viewModel: viewModel)
        case .clip:      ClipModeView(viewModel: viewModel)
        case .plugin:    PluginModeView(viewModel: viewModel)
        case .keyword:   ResultsListView(viewModel: viewModel)
        }
    }
}
