import Foundation
import SwiftUI

@MainActor
final class PluginModeController: ObservableObject, ModeStateController {
    static let shared = PluginModeController()
    
    @Published var currentPlugin: Plugin?
    @Published private var items: [PluginItem] = []
    
    private let pluginManager = PluginManager.shared
    private let pluginExecutor = PluginExecutor.shared
    
    private init() {}
    
    // MARK: - ModeStateController Protocol
    var displayableItems: [any DisplayableItem] { items }
    var displayName: String { "Plugin" }
    var iconName: String { "puzzlepiece" }
    var placeholder: String { currentPlugin?.manifest.placeholder ?? "输入插件命令..." }
    var modeDescription: String? { "Plugin mode" }
    var prefix: String? { currentPlugin?.command }
    
    func shouldActivate(for text: String) -> Bool {
        guard let command = text.components(separatedBy: " ").first else { return false }
        return pluginManager.canHandleCommand(command)
    }
    
    func enterMode(with text: String) {
        guard let command = text.components(separatedBy: " ").first,
              let plugin = pluginManager.findPlugin(by: command)
        else {
            currentPlugin = nil
            items = []
            return
        }
        
        currentPlugin = plugin
        Task {
            do {
                let result = try await pluginExecutor.execute(plugin: plugin)
                if result.success {
                    // 处理执行结果
                }
            } catch {
                print("插件执行失败: \(error)")
            }
        }
    }
    
    func handleInput(_ text: String) {
        guard let plugin = currentPlugin else { return }
        
        // 移除命令前缀，只保留搜索查询
        let query = text.replacingOccurrences(of: plugin.command, with: "").trimmingCharacters(in: .whitespaces)
        
        Task {
            do {
                let result = try await pluginExecutor.execute(plugin: plugin, with: [query])
                if result.success {
                    // 处理执行结果
                }
            } catch {
                print("插件搜索失败: \(error)")
            }
        }
    }
    
    func executeAction(at index: Int) -> Bool {
        guard let plugin = currentPlugin,
              index >= 0 && index < items.count
        else { return false }
        
        let item = items[index]
        Task {
            do {
                let result = try await pluginExecutor.execute(plugin: plugin, with: [item.action ?? ""])
                if result.success {
                    // 处理执行结果
                }
            } catch {
                print("插件动作执行失败: \(error)")
            }
        }
        
        return true
    }
    
    func shouldExit(for text: String) -> Bool {
        guard let plugin = currentPlugin else { return true }
        if text.hasPrefix("/") {
            let commandPart = text.components(separatedBy: " ").first ?? ""
            return commandPart != plugin.command
        }
        return true
    }
    
    func cleanup() {
        currentPlugin = nil
        items = []
    }
    
    func makeRowView(for item: any DisplayableItem, isSelected: Bool, index: Int, handleItemSelection: @escaping (Int) -> Void) -> AnyView {
        if let pluginItem = item as? PluginItem {
            return AnyView(PluginItemRowView(item: pluginItem, isSelected: isSelected, index: index)
                .onTapGesture { handleItemSelection(index) })
        }
        return AnyView(EmptyView())
    }
    
    func makeContentView() -> AnyView {
        return AnyView(PluginModeView(viewModel: LauncherViewModel.shared))
    }
    
    static func getHelpText() -> [String] {
        return [
            "使用 / 开始插件命令",
            "输入参数以搜索或执行操作",
            "使用 ↑↓ 或数字键选择结果",
            "按 Enter 执行所选项"
        ]
    }
    
    // MARK: - Internal Methods
    func updateItems(_ items: [PluginItem]) {
        self.items = items
    }
}
