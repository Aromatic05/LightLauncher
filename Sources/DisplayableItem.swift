import SwiftUI
import AppKit

protocol DisplayableItem: Hashable, Identifiable {
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
}

// AppInfo 遵守 DisplayableItem 协议
extension AppInfo: DisplayableItem {
    var title: String { name }
    var subtitle: String? { url.path }
    // id 和 icon 已在 AppInfo 内部实现
}

// RunningAppInfo 遵守 DisplayableItem 协议
extension RunningAppInfo: DisplayableItem {
    var title: String { name }
    var subtitle: String? { bundleIdentifier }
    // id 和 icon 已在结构体内部实现
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

// BrowserItem 遵守 DisplayableItem 协议
extension BrowserItem: DisplayableItem {
    var subtitle: String? { url }
    var icon: NSImage? { nil }
}
