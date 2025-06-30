import Foundation
import AppKit

// MARK: - 基础命令协议
@MainActor
protocol LauncherCommandHandler {
    var trigger: String { get }
    var description: String { get }
    var mode: LauncherMode { get }
    
    func execute(in viewModel: LauncherViewModel) -> Bool
    func handleInput(_ text: String, in viewModel: LauncherViewModel)
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool
}

// MARK: - 默认启动命令
@MainActor
struct LaunchCommand: LauncherCommandHandler {
    let trigger = ""
    let description = "Launch applications"
    let mode = LauncherMode.launch
    
    func execute(in viewModel: LauncherViewModel) -> Bool {
        viewModel.switchToLaunchMode()
        return true
    }
    
    func handleInput(_ text: String, in viewModel: LauncherViewModel) {
        viewModel.filterApps(searchText: text)
    }
    
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return viewModel.launchSelectedApp()
    }
}
