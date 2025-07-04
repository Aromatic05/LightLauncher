import Foundation
import AppKit

@MainActor
class PluginStateController: ModeStateController {
    var pluginItems: [PluginItem] = []
    let mode: LauncherMode = .plugin
    
    var displayableItems: [any DisplayableItem] {
        pluginItems
    }
    
    func activate() {
        // 可根据需要加载插件数据
    }
    func deactivate() {
        pluginItems = []
    }
    func update(for searchText: String) {
        // 由插件命令处理器驱动
    }
    func executeAction(at index: Int) -> PostAction? {
        guard index >= 0 && index < pluginItems.count else { return .keepWindowOpen }
        // 具体执行逻辑由插件命令处理器实现
        return .hideWindow
    }
    
    // 插件相关接口
    func switchToPluginMode(with plugin: Plugin) {
        // 可在此处实现插件激活逻辑
    }
    func getActivePlugin() -> Plugin? {
        // 可返回当前激活插件
        return nil
    }
    func getPluginShouldHideWindowAfterAction() -> Bool {
        // 可根据插件配置返回是否应隐藏窗口
        return true
    }
    func updatePluginResults(_ items: [PluginItem]) {
        self.pluginItems = items
    }
    func executePluginAction(selectedIndex: Int) -> Bool {
        return executeAction(at: selectedIndex) == .hideWindow
    }
    func handlePluginSearch(_ text: String) {
        update(for: text)
    }
    func clearPluginState() {
        self.pluginItems = []
    }
}

