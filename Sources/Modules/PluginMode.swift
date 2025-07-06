import Foundation
import os
import SwiftUI
import AppKit

// MARK: - 插件模式控制器
@MainActor
class PluginModeController: NSObject, ModeStateController, ObservableObject {
    @Published var pluginItems: [PluginItem] = []
    private let pluginManager = PluginManager.shared
    private var activePlugin: Plugin?
    var prefix: String? { activePlugin?.command ?? "!" }
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        pluginItems.map { $0 as any DisplayableItem }
    }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        // 只要是插件命令前缀就激活
        if let command = text.components(separatedBy: " ").first {
            return pluginManager.canHandleCommand(command)
        }
        return false
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        guard let command = text.components(separatedBy: " ").first,
              let plugin = pluginManager.activatePlugin(command: command),
              plugin.isEnabled else {
            pluginItems = []
            activePlugin = nil
            return
        }
        activePlugin = plugin
        pluginManager.injectViewModel(viewModel, for: command)
        pluginManager.executePluginSearch(command: plugin.command, query: "")
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        guard let plugin = activePlugin else { return }
        pluginManager.executePluginSearch(command: plugin.command, query: text)
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        guard let plugin = activePlugin else { return false }
        guard index >= 0 && index < pluginItems.count else { return false }
        let item = pluginItems[index]
        if let action = item.action, !action.isEmpty {
            return pluginManager.executePluginAction(command: plugin.command, action: action)
        }
        return true
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 输入不再匹配当前插件命令时退出
        guard let plugin = activePlugin else { return true }
        if text.hasPrefix("/") {
            let commandPart = text.components(separatedBy: " ").first ?? text
            return commandPart != plugin.command
        } else {
            return true
        }
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        if let plugin = activePlugin {
            pluginManager.cleanupPlugin(command: plugin.command)
        }
        activePlugin = nil
        pluginItems = []
    }
    // 生成内容视图
    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        return AnyView(PluginModeView(viewModel: viewModel))
    }
    // --- 辅助方法 ---
    func updatePluginResults(_ items: [PluginItem]) {
        self.pluginItems = items
    }
    func getActivePlugin() -> Plugin? {
        return activePlugin
    }
    func clearPluginState() {
        self.pluginItems = []
        self.activePlugin = nil
    }

    static func getHelpText() -> [String] {
        return [
            "Type to search applications",
            "Press ↑↓ arrows or numbers 1-6 to select",
            "Type / to see all commands",
            "Press Esc to close"
        ]
    }
}