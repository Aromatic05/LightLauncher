import AppKit
import SwiftUI

/// 负责管理应用所有窗口的创建、显示、隐藏和状态。
///
/// 它封装了主启动器窗口和设置窗口的全部逻辑，并作为窗口的代理来响应事件。
/// 通过将窗口管理逻辑集中于此，极大地简化了 AppDelegate 的职责。
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    // MARK: - 属性
    private var launcherWindow: LauncherWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    /// 记录显示主窗口前的前台应用
    private var previousFrontmostApp: NSRunningApplication?
    /// 显示关于窗口
    public func showAboutWindow() {
        if aboutWindow != nil {
            aboutWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let aboutView = AboutView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于 LightLauncher"
        window.contentView = NSHostingView(rootView: aboutView)
        window.isReleasedWhenClosed = false
        window.level = .floating
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }
    
    /// 内部持有一个输入法管理器，在窗口显示/隐藏时调用。
    private let inputMethodManager = InputMethodManager()
    
    /// 用于防止在隐藏动画期间重复调用 hideWindow。
    private var isHidingWindow = false
    
    // MARK: - 依赖
    
    /// 对 ViewModel 的弱引用，用于创建视图和传递给视图。
    private weak var viewModel: LauncherViewModel?

    // MARK: - 初始化
    
    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
        super.init()
        // 在初始化时就创建好主窗口。
        setupLauncherWindow()
        // 监听隐藏窗口的通知。
        setupNotificationObservers()
    }
    
    // MARK: - 公开方法
    
    /// 切换主启动器窗口的显示/隐藏状态。
    public func toggleMainWindow() {
        guard let window = launcherWindow else { return }
        if window.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }
    
    /// 显示主启动器窗口。
    public func showMainWindow() {
        guard let window = launcherWindow, let viewModel = viewModel else { return }
        // 记录显示主窗口前的前台应用
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        isHidingWindow = false
        centerWindow(window)
        viewModel.clearSearch()
        inputMethodManager.switchToEnglish()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(window.contentView)
        KeyboardEventHandler.shared.startMonitoring()
    }
    
    /// 显示设置窗口。
    public func showSettingsWindow() {
        if settingsWindow == nil {
            setupSettingsWindow()
        }
        
        hideMainWindow(shouldActivatePreviousApp: false)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(settingsWindow?.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 私有窗口设置
    
    private func setupLauncherWindow() {
        guard let viewModel = viewModel else { return }
        
        // KeyHandlingView 负责捕获键盘事件，应与窗口逻辑紧密耦合。
        let contentView = LauncherView(viewModel: viewModel)
        let hostingView = KeyHandlingView(rootView: contentView, viewModel: viewModel)
        
        launcherWindow = LauncherWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        launcherWindow?.contentView = hostingView
        launcherWindow?.level = .floating
        launcherWindow?.backgroundColor = .clear
        launcherWindow?.isOpaque = false
        launcherWindow?.hasShadow = true
        launcherWindow?.delegate = self // 将自身设为代理
    }
    
    private func setupSettingsWindow() {
        let settingsView = SettingsView()
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.title = "LightLauncher 设置"
        settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        settingsWindow?.isReleasedWhenClosed = false // 避免关闭后被销毁
        settingsWindow?.level = .normal
        centerWindow(settingsWindow!)
    }
    
    private func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2 + 50 // 稍微偏上
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - 窗口隐藏逻辑
    
    /// 隐藏主启动器窗口。
    public func hideMainWindow(shouldActivatePreviousApp: Bool = true) {
        KeyboardEventHandler.shared.stopMonitoring()
        if isHidingWindow { return }
        isHidingWindow = true

        launcherWindow?.orderOut(nil)
        viewModel?.clearSearch()

        inputMethodManager.restorePreviousInputMethod()

        if !shouldActivatePreviousApp {
            // 如果不需要激活前一个应用，简单重置标志位即可。
            DispatchQueue.main.async { self.isHidingWindow = false }
            return
        }

        // 只有当前没有处于激活状态的应用时，才激活记录的前一个应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            let hasActivatedApp = NSWorkspace.shared.runningApplications.contains {
                $0.isActive && !$0.isHidden && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            if !hasActivatedApp,
               let previousApp = self.previousFrontmostApp,
               previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousApp.activate(options: [])
            }
            // 清空记录，避免下次误用
            self.previousFrontmostApp = nil
            Task { @MainActor in self.isHidingWindow = false }
        }

    }
    
    // MARK: - 通知处理
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideWindowNotification(_:)),
            name: .hideWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideWindowWithoutActivatingNotification(_:)),
            name: .hideWindowWithoutActivating,
            object: nil
        )
    }
    
    @objc private func handleHideWindowNotification(_ notification: Notification) {
        hideMainWindow(shouldActivatePreviousApp: true)
    }
    
    @objc private func handleHideWindowWithoutActivatingNotification(_ notification: Notification) {
        hideMainWindow(shouldActivatePreviousApp: false)
    }

    // MARK: - NSWindowDelegate
    
    /// 当窗口失去焦点时，自动隐藏。
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow == launcherWindow {
            hideMainWindow()
        }
    }
}


// MARK: - 附属UI组件
// 这些与窗口紧密相关的视图和子类，适合放在同一个文件中。

/// 一个自定义的 NSWindow，确保它可以成为主窗口和键盘响应者。
class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
    override var acceptsFirstResponder: Bool { return true }
}

/// 一个自定义的 NSHostingView，用于确保键盘焦点能够正确传递。
class KeyHandlingView: NSHostingView<LauncherView> {
    private let viewModel: LauncherViewModel
    
    init(rootView: LauncherView, viewModel: LauncherViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
    }
    
    @available(*, unavailable)
    required init(rootView: LauncherView) {
        fatalError("Use init(rootView:viewModel:) instead")
    }
    
    @available(*, unavailable)
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { return true }
}

// MARK: - 自定义通知名称
// 将通知名称的定义也集中管理。
extension Notification.Name {
    static let hideWindow = Notification.Name("hideWindow")
    static let hideWindowWithoutActivating = Notification.Name("hideWindowWithoutActivating")
    // hotKeyChanged 由其他文件定义，这里不再重复声明
}
