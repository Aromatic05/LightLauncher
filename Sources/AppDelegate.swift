import AppKit
import Carbon
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: LauncherViewModel?
    private var settingsManager = SettingsManager.shared
    private var configManager = ConfigManager.shared
    private var statusMenuManager: StatusMenuManager?
    private var windowManager: WindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动权限检查
        Task { @MainActor in
            PermissionManager.shared.performStartupPermissionCheck()
        }

        AppScanner.shared.scanForApplications()
        PreferencePaneScanner.shared.scanForPreferencePanes()
        NSApp.setActivationPolicy(.accessory)
        _ = ClipboardManager.shared
        _ = PermissionManager.shared

        viewModel = LauncherViewModel.shared
        LauncherViewModel.shared.switchController(from: nil, to: .launch)
        if let viewModel = viewModel {
            windowManager = WindowManager(viewModel: viewModel)
        }
        
        setupStatusMenuManager()
        setupAllHotkeys()
        setupPluginSystem()
        
        setupHotkeyObservers()
    }
    
    /// 统一设置所有热键。
    private func setupAllHotkeys() {
        // 1. 获取所有热键配置
        let mainHotkeyConfig = configManager.config.hotKey
        let mainHotkey = HotKey(keyCode: mainHotkeyConfig.keyCode, modifiers: mainHotkeyConfig.modifiers)
        let customHotkeys = configManager.config.customHotKeys
        
        // 2. 调用统一的静态注册方法
        HotkeyManager.registerAll(mainHotkey: mainHotkey, customHotkeys: customHotkeys)
    }
    
    private func setupHotkeyObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainHotkeyDidTrigger),
            name: .mainHotkeyTriggered,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(customHotkeyDidTrigger(notification:)),
            name: .customHotkeyTriggered,
            object: nil
        )
    }

    @objc private func mainHotkeyDidTrigger() {
        windowManager?.toggleMainWindow()
    }

    @objc private func customHotkeyDidTrigger(notification: Notification) {
        guard let hotkeyID = notification.userInfo?["hotkeyID"] as? UInt32 else { return }
        
        Task { @MainActor in
            guard let config = HotkeyManager.getConfig(for: hotkeyID) else { return }
            self.windowManager?.showMainWindow()
            self.viewModel?.updateQuery(newQuery: config.text)
        }
    }

    private func setupStatusMenuManager() {
        let actions = StatusMenuManager.Actions(
            showLauncher: { [weak self] in self?.showWindow() },
            openSettings: { [weak self] in self?.showSettingsWindow() },
            showAbout: { [weak self] in self?.windowManager?.showAboutWindow() },
            quitApp: { NSApplication.shared.terminate(nil) }
        )
        statusMenuManager = StatusMenuManager(
            actions: actions,
            hotkeyDescription: settingsManager.getHotKeyDescription()
        )
    }

    private func setupPluginSystem() {
        Task {
            await PluginManager.shared.loadAllPlugins()
            let plugins = PluginManager.shared.getLoadedPlugins()
            print("✅ 插件系统就绪，已加载 \(plugins.count) 个插件")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Window and Action Handlers
    private func showWindow() {
        windowManager?.showMainWindow()
    }

    private func showSettingsWindow() {
        windowManager?.showSettingsWindow()
    }

    private func hideWindow() {
        windowManager?.hideMainWindow()
    }

    private func hideWindow(shouldActivatePreviousApp: Bool) {
        windowManager?.hideMainWindow(shouldActivatePreviousApp: shouldActivatePreviousApp)
    }

    /// **[已修改]** 更新热键现在只需要重新调用统一的设置方法。
    private func updateGlobalHotkey() {
        // 重新注册所有热键
        setupAllHotkeys()
        // 更新菜单栏的提示信息
        statusMenuManager?.updateTooltip(with: configManager.getHotKeyDescription())
    }
}