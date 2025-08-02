import Foundation
import AppKit
import Combine
import SwiftUI

// MARK: - DisplayableItem 协议
protocol DisplayableItem: Hashable, Identifiable {
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView
    @MainActor
    func executeAction() -> Bool
}

// MARK: - 模式状态控制器协议（清晰版）
@MainActor
protocol ModeStateController: AnyObject {
    static var shared: Self { get }
    /// 当前模式下所有可显示项（用于 UI 统一绑定）
    var displayableItems: [any DisplayableItem] { get }
    /// 用于通知数据变化的发布者
    var dataDidChange: PassthroughSubject<Void, Never> { get }

    // 新增：模式元信息属性
    var displayName: String { get }
    var iconName: String { get }
    var placeholder: String { get }
    var modeDescription: String? { get }
    /// 模式的触发前缀（如 /k），可选
    var prefix: String? { get }
    var mode: LauncherMode { get }
    var interceptedKeys: Set<KeyEvent> { get }

    // 处理输入：模式激活后每次输入的处理（如搜索、过滤等）
    func handleInput(arguments: String)

    func handle(keyEvent: KeyEvent) -> Bool

    // 执行动作：用户确认选择时的操作
    func executeAction(at index: Int) -> Bool

    // 模式退出或切换时的清理操作
    func cleanup()

    func makeContentView() -> AnyView

    func getHelpText() -> [String]
}

extension ModeStateController {
    var interceptedKeys: Set<KeyEvent> {
        return []
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        return false
    }

    func makeContentView() -> AnyView {
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyView())
        }
    }

    func getHelpText() -> [String] {
        return []
    }
}