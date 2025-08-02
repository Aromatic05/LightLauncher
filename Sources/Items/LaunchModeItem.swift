import Foundation
import SwiftUI

// MARK: - 应用信息结构
struct AppInfo: Identifiable, Hashable, DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(AppRowView(app: self, isSelected: isSelected, index: index, mode: .launch))
    }
    let name: String
    let url: URL
    
    // 使用 URL 路径作为唯一标识符，避免重复应用
    var id: String {
        url.path
    }
    
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    // DisplayableItem 协议实现
    var displayName: String { name }
    var title: String { name }
    var subtitle: String? { url.path }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.url.path == rhs.url.path
    }

    @MainActor
    func executeAction() -> Bool {
        let success = NSWorkspace.shared.open(url)
        if success {
            LaunchModeController.shared.incrementUsage(for: name)
        }
        return success
    }
}

struct SystemCommandItem: DisplayableItem {
    let id = UUID()
    let title: String         // 用于查找（英文）
    let displayName: String   // 用于界面显示（中文）
    let subtitle: String?
    let icon: NSImage?
    let action: () -> Void

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SystemCommandRowView(command: self, isSelected: isSelected, index: index))
    }

    // Hashable/Equatable 实现，使用 id 唯一
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: SystemCommandItem, rhs: SystemCommandItem) -> Bool {
        lhs.id == rhs.id
    }

    @MainActor
    func executeAction() -> Bool {
        action()
        return true // 执行命令后返回 true
    }
}

struct PreferencePaneItem: DisplayableItem {
    let id: UUID = UUID()
    let title: String
    let subtitle: String?
    let icon: NSImage?
    let url: URL

    // 只用路径做哈希和判等，保证唯一
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    static func == (lhs: PreferencePaneItem, rhs: PreferencePaneItem) -> Bool {
        lhs.url.path == rhs.url.path
    }

    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(PreferencePaneRowView(pane: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        let success = NSWorkspace.shared.open(url)
        return success // 返回是否成功打开设置面板
    }
}