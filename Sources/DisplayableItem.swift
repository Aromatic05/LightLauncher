import SwiftUI
import AppKit

protocol DisplayableItem: Hashable, Identifiable {
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
}

// FileItem 遵守 DisplayableItem 协议
extension FileItem: DisplayableItem {
    var title: String { name }
    var subtitle: String? { url.path }
    // id 和 icon 已在结构体内部实现
}

// PluginItem 遵守 DisplayableItem 协议
extension PluginItem: DisplayableItem {
    var icon: NSImage? {
        // 可根据 iconName 字段类型（SF Symbol 或 Base64）自定义转换
        nil
    }
}


