import AppKit
import Foundation
import SwiftUI

// MARK: - 插件返回的结果项
struct PluginItem: Identifiable, Hashable, Sendable, DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(PluginItemRowView(item: self, isSelected: isSelected, index: index))
    }
    let id = UUID()
    let title: String
    let subtitle: String?
    let iconName: String?  // SF Symbol 名称或 Base64 图片字符串
    let action: String?  // 执行动作的标识符
    var icon: NSImage? {
        // 根据 iconName 的类型返回对应的 NSImage
        if let iconName = iconName {
            if iconName.hasPrefix("SF:") {
                return NSImage(
                    systemSymbolName: String(iconName.dropFirst(3)), accessibilityDescription: nil)
            } else if iconName.hasPrefix("base64:") {
                if let data = Data(base64Encoded: String(iconName.dropFirst(7))),
                    let image = NSImage(data: data)
                {
                    return image
                }
            }
        }
        return nil
    }

    init(
        title: String, subtitle: String? = nil, iconName: String? = nil,
        action: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.action = action
    }

    // MARK: - Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PluginItem, rhs: PluginItem) -> Bool {
        return lhs.id == rhs.id
    }

    @MainActor
    func executeAction() -> Bool {
        // if case .showingPluginList(let items) = internalMode {
        //     let command = String(action.dropFirst("select_plugin:".count))
        //     handleInput(arguments: command)
        //     return true
        // }

        guard let instance = PluginModeController.shared.activeInstance,
            let action = self.action
        else {
            return false
        }
        return instance.executeAction(action)
    }
}

// MARK: - 插件结果集合
struct PluginResult {
    let items: [PluginItem]
    let hasMore: Bool  // 是否还有更多结果
    let totalCount: Int?  // 总结果数（可选）

    init(items: [PluginItem], hasMore: Bool = false, totalCount: Int? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.totalCount = totalCount
    }

    var isEmpty: Bool {
        return items.isEmpty
    }

    var count: Int {
        return items.count
    }
}
