import AppKit
import SwiftUI
import Carbon
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: LauncherViewModel?
    private var settingsManager = SettingsManager.shared
    private var configManager = ConfigManager.shared
    private var hotkeyManager: HotkeyManager?
    private var statusMenuManager: StatusMenuManager?
    private var windowManager: WindowManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppScanner.shared.scanForApplications()
        PreferencePaneScanner.shared.scanForPreferencePanes()
        NSApp.setActivationPolicy(.accessory) // No dock icon
        _ = ClipboardManager.shared

        /// Initialize the shared view model
        viewModel = LauncherViewModel.shared
        LauncherViewModel.shared.switchController(from: nil, to: .launch)
        if let viewModel = viewModel {
            windowManager = WindowManager(viewModel: viewModel)
        }
        setupStatusMenuManager()
        setupHotkeyManager()
        setupPluginSystem()

    }
    
    private func setupHotkeyManager() {
        let config = configManager.config.hotKey
        let hotKey = HotKey(keyCode: config.keyCode, modifiers: config.modifiers)
        hotkeyManager = HotkeyManager(config: hotKey) { [weak self] in
            self?.handleHotKeyPressed()
        }
        hotkeyManager?.registerInitialHotkey()
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
        // 初始化插件管理器并发现插件
        Task {
            await PluginManager.shared.loadAllPlugins()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let plugins = PluginManager.shared.getLoadedPlugins()
                print("✅ 插件系统就绪，已加载 \(plugins.count) 个插件")
            }
        }
    }

    deinit {
        // Cleanup will be handled when the app terminates
    }

    private func handleHotKeyPressed() {
        windowManager?.toggleMainWindow()
    }
    
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
    
    private func updateGlobalHotkey() {
        let config = configManager.config.hotKey
        let hotKey = HotKey(keyCode: config.keyCode, modifiers: config.modifiers)
        hotkeyManager?.updateHotkey(with: hotKey)
        statusMenuManager?.updateTooltip(with: configManager.getHotKeyDescription())
    }
}
