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
}

