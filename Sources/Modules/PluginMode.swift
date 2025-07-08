import Foundation
import os
import SwiftUI
import AppKit

// MARK: - 插件模式控制器
@MainActor
final class PluginModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = PluginModeController()
    private override init() {}
    @Published var pluginItems: [PluginItem] = []
    private let pluginManager = PluginManager.shared
    private var activePlugin: Plugin?
    var prefix: String? { activePlugin?.command ?? "!" }
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        pluginItems.map { $0 as any DisplayableItem }
    }
    // 元信息属性
    var displayName: String { "Plugin" }
    var iconName: String { "puzzlepiece" }
    var placeholder: String { "Plugin mode..." }
    var modeDescription: String? { "Plugin-powered functionality" }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        // 只要是插件命令前缀就激活
        if let command = text.components(separatedBy: " ").first {
            return pluginManager.canHandleCommand(command)
        }
        return false
    }
    // 2. 进入模式
    func enterMode(with text: String) {
        guard let command = text.components(separatedBy: " ").first else {
            pluginItems = []
            activePlugin = nil
            return
        }
        // 如果当前 activePlugin 已经是目标 command，直接 return，避免重复激活
        if let current = activePlugin, current.command == command {
            return
        }
        guard let plugin = pluginManager.activatePlugin(command: command), plugin.isEnabled else {
            pluginItems = []
            activePlugin = nil
            return
        }
        activePlugin = plugin
        PluginExecutor.shared.injectViewModel(LauncherViewModel.shared, for: command)
        PluginExecutor.shared.executePluginSearch(command: plugin.command, query: "")
        LauncherViewModel.shared.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String) {
        guard let plugin = activePlugin, plugin.context != nil else { return }
        PluginExecutor.shared.executePluginSearch(plugin: plugin, query: text)
        LauncherViewModel.shared.selectedIndex = 0
        print("PluginModeController: handleInput called with text: \(text)")
        print(pluginItems.map { $0.title }.joined(separator: ", "))
    }
    // 4. 执行动作
    func executeAction(at index: Int) -> Bool {
        guard let plugin = activePlugin else { return false }
        guard index >= 0 && index < pluginItems.count else { return false }
        let item = pluginItems[index]
        if let action = item.action, !action.isEmpty {
            return PluginExecutor.shared.executePluginAction(command: plugin.command, action: action)
        }
        return true
    }
    // 5. 退出条件
    func shouldExit(for text: String) -> Bool {
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
    func cleanup() {
        if let plugin = activePlugin {
            Task { await PluginExecutor.shared.cleanupPlugin(command: plugin.command) }
        }
        activePlugin = nil
        pluginItems = []
    }
    // 生成内容视图
    func makeContentView() -> AnyView {
        return AnyView(PluginModeView(viewModel: LauncherViewModel.shared))
    }
    // --- 辅助方法 ---
    func updatePluginResults(_ items: [PluginItem]) {
        self.pluginItems = items
        print("updatePluginResults: \(items.map { $0.title }.joined(separator: ", "))")
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
    // 渲染 PluginItem 行视图
    func makeRowView(for item: any DisplayableItem, isSelected: Bool, index: Int, handleItemSelection: @escaping (Int) -> Void) -> AnyView {
        if let pluginItem = item as? PluginItem {
            return AnyView(
                PluginItemRowView(item: pluginItem, isSelected: isSelected, index: index)
                    .id(index)
                    .onTapGesture { handleItemSelection(index) }
            )
        } else {
            return AnyView(EmptyView())
        }
    }
}