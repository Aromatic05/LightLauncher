import AppKit
import SwiftUI

/// 负责管理状态栏图标（NSStatusItem）及其菜单的服务。
///
/// 它封装了状态栏图标的创建、菜单的构建以及相关动作的处理，
/// 使得 AppDelegate 只需在启动时创建这个管理器即可。
@MainActor
final class StatusMenuManager {

    // MARK: - 属性
    
    /// 持有系统状态栏项目。设为私有，外部不应直接访问。
    private var statusItem: NSStatusItem?

    // MARK: - 类型定义
    
    /// 使用一个结构体来聚合所有菜单项需要执行的动作，
    /// 通过闭包由外部注入，实现解耦。
    struct Actions {
        let showLauncher: () -> Void
        let openSettings: () -> Void
        let showAbout: () -> Void
        let quitApp: () -> Void
    }
    
    private let actions: Actions

    // MARK: - 初始化
    
    init(actions: Actions, hotkeyDescription: String) {
        self.actions = actions
        setupStatusItem(hotkeyDescription: hotkeyDescription)
    }
    
    // MARK: - 公开方法
    
    /// 更新状态栏图标的工具提示文本。
    /// - Parameter description: 新的热键描述文本。
    public func updateTooltip(with description: String) {
        statusItem?.button?.toolTip = "LightLauncher - \(description)"
    }

    // MARK: - 私有方法
    
    /// 初始化并配置状态栏图标和菜单。
    private func setupStatusItem(hotkeyDescription: String) {
        // 1. 创建状态栏项目实例。
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // 2. 配置按钮图标和初始工具提示。
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "LightLauncher")
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.toolTip = "LightLauncher - \(hotkeyDescription)"
        }
        
        // 3. 创建并关联菜单。
        statusItem?.menu = buildMenu()
    }
    
    /// 构建状态栏菜单。
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "显示启动器", action: #selector(showLauncherAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于", action: #selector(showAboutAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitAppAction), keyEquivalent: "q"))
        
        // 将所有菜单项的 target 设置为 self，以便响应点击事件。
        for item in menu.items {
            item.target = self
        }
        
        return menu
    }
    
    // MARK: - @objc 动作方法
    // 这些方法将调用初始化时注入的闭包，从而将事件传递出去。
    
    @objc private func showLauncherAction() {
        actions.showLauncher()
    }
    
    @objc private func openSettingsAction() {
        actions.openSettings()
    }
    
    @objc private func showAboutAction() {
        actions.showAbout()
    }
    
    @objc private func quitAppAction() {
        actions.quitApp()
    }
}
