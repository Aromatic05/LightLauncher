import Foundation
import AppKit
import Combine

// MARK: - 模式状态控制器协议（清晰版）
@MainActor
protocol ModeStateController {
    // 1. 触发条件：什么输入会激活该模式
    /// 返回 true 表示该输入应激活本模式
    func shouldActivate(for text: String) -> Bool

    /// 模式的触发前缀（如 /k），可选
    var prefix: String? { get }

    /// 当前模式下所有可显示项（用于 UI 统一绑定）
    var displayableItems: [any DisplayableItem] { get }

    // 2. 进入模式：初始化 ViewModel 状态
    func enterMode(with text: String, viewModel: LauncherViewModel)

    // 3. 处理输入：模式激活后每次输入的处理（如搜索、过滤等）
    func handleInput(_ text: String, viewModel: LauncherViewModel)

    // 4. 执行动作：用户确认选择时的操作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool

    // 5. 退出条件：是否应退出本模式，返回 true 表示应回到默认模式
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool

    // 6. 模式退出或切换时的清理操作
    func cleanup(viewModel: LauncherViewModel)
}

protocol CommandSuggestionProvider {
    static func getHelpText() -> [String]
}

// MARK: - 通用命令建议管理器
@MainActor
struct CommandSuggestionManager {
    static func getSuggestions(for text: String) -> [LauncherCommand] {
        if text.isEmpty {
            return []
        }
        
        // 统一使用 getCommandSuggestions，这个方法已经包含了插件命令
        return LauncherCommand.getCommandSuggestions(for: text)
    }
}