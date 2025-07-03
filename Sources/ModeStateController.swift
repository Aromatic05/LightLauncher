import Foundation

// 定义操作完成后的行为
enum PostAction {
    case hideWindow
    case keepWindowOpen
}

@MainActor
protocol ModeStateController: ObservableObject {
    // 核心数据：对外暴露一个通用的、可供 SwiftUI 绑定的列表
    var displayableItems: [any DisplayableItem] { get }
    // 标识自己是哪种模式
    var mode: LauncherMode { get }
    // 当模式被激活时调用（例如：加载初始数据）
    func activate()
    // 当模式被停用时调用（例如：清理状态）
    func deactivate()
    // 当搜索文本变化时调用
    func update(for searchText: String)
    // 当用户按下回车键时调用
    func executeAction(at index: Int) -> PostAction?
}
