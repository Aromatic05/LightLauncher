import AppKit
import SwiftUI
import Carbon

// 输入法管理器
class InputMethodManager {
    private var previousInputSource: TISInputSource?
    
    // 切换到英文输入法
    func switchToEnglish() {
        // 保存当前输入法
        previousInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        
        // 获取英文输入法列表
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let inputSources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return
        }
        
        let count = CFArrayGetCount(inputSources)
        for i in 0..<count {
            guard let inputSource = CFArrayGetValueAtIndex(inputSources, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(inputSource).takeUnretainedValue()
            
            // 获取输入法ID
            guard let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
            
            // 查找ABC输入法（美式英语键盘）
            if id == "com.apple.keylayout.ABC" || id == "com.apple.keylayout.US" {
                TISSelectInputSource(source)
                break
            }
        }
    }
    
    // 恢复之前的输入法
    func restorePreviousInputMethod() {
        if let previous = previousInputSource {
            TISSelectInputSource(previous)
            previousInputSource = nil
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var appScanner = AppScanner()
    private var viewModel: LauncherViewModel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var modifierMonitor: Any?
    private var inputMethodManager = InputMethodManager()
    private var settingsManager = SettingsManager.shared
    private var configManager = ConfigManager.shared
    private var statusItem: NSStatusItem?
    
    // 添加标志来防止重复隐藏窗口
    private var isHidingWindow = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // No dock icon
        
        setupViewModel()
        setupWindow()
        setupStatusItem()
        setupGlobalHotkey()
        setupNotificationObservers()
        
        // Start scanning for applications
        appScanner.scanForApplications()
    }
    
    private func setupViewModel() {
        viewModel = LauncherViewModel(appScanner: appScanner)
    }
    
    private func setupWindow() {
        guard let viewModel = viewModel else { return }
        
        let contentView = LauncherView(viewModel: viewModel)
        let hostingView = KeyHandlingView(rootView: contentView, viewModel: viewModel)
        
        window = LauncherWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window?.contentView = hostingView
        window?.level = .floating
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.hasShadow = true
        window?.delegate = self
        
        centerWindow()
    }
    
    private func centerWindow() {
        guard let window = window,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2 + 50 // Slightly above center
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func setupGlobalHotkey() {
        let hotKeyId = EventHotKeyID(signature: FourCharCode("htk1".fourCharCodeValue), id: 1)
        
        var hotKeyRef: EventHotKeyRef?
        
        // 对于单独的修饰键，使用特殊的keyCode处理
        let keyCode = configManager.config.hotKey.keyCode == 0 ? UInt32(kVK_F13) : configManager.config.hotKey.keyCode
        
        let status = RegisterEventHotKey(
            keyCode,
            configManager.config.hotKey.modifiers,
            hotKeyId,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            
            // 如果是单独的修饰键，需要设置特殊的事件处理
            if configManager.config.hotKey.keyCode == 0 {
                setupModifierOnlyHotkey()
            } else {
                setupRegularHotkey()
            }
        }
    }
    
    private func setupRegularHotkey() {
        // Install a simple event handler for regular hotkeys
        var eventHandler: EventHandlerRef?
        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
        
        let callback: EventHandlerProcPtr = { (_, event, userData) -> OSStatus in
            if let userData = userData {
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    appDelegate.handleHotKeyPressed()
                }
            }
            return noErr
        }
        
        let installStatus = Carbon.InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if installStatus == noErr {
            self.eventHandler = eventHandler
        }
    }
    
    private func setupModifierOnlyHotkey() {
        // For modifier-only hotkeys, we need to monitor flag changes
        self.modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleModifierOnlyHotkey(event)
            }
        }
    }
    
    private func handleModifierOnlyHotkey(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = event.modifierFlags
        let settingsModifiers = configManager.config.hotKey.modifiers
        
        // 检查是否是我们设置的修饰键的释放事件
        var isOurModifier = false
        
        switch settingsModifiers {
        case 0x100008: // 左 Command
            isOurModifier = (keyCode == UInt32(kVK_Command) && !modifiers.contains(.command))
        case 0x100010: // 右 Command
            isOurModifier = (keyCode == UInt32(kVK_RightCommand) && !modifiers.contains(.command))
        case 0x100020: // 左 Option
            isOurModifier = (keyCode == UInt32(kVK_Option) && !modifiers.contains(.option))
        case 0x100040: // 右 Option
            isOurModifier = (keyCode == UInt32(kVK_RightOption) && !modifiers.contains(.option))
        case 0x100001: // 左 Control
            isOurModifier = (keyCode == UInt32(kVK_Control) && !modifiers.contains(.control))
        case 0x102000: // 右 Control
            isOurModifier = (keyCode == UInt32(kVK_RightControl) && !modifiers.contains(.control))
        case 0x100002: // 左 Shift
            isOurModifier = (keyCode == UInt32(kVK_Shift) && !modifiers.contains(.shift))
        case 0x100004: // 右 Shift
            isOurModifier = (keyCode == UInt32(kVK_RightShift) && !modifiers.contains(.shift))
        default:
            break
        }
        
        // 确保在释放时没有其他修饰键被按住
        if isOurModifier && !modifiers.contains([.command, .option, .control, .shift]) {
            handleHotKeyPressed()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("hideWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideWindow()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("hideWindowWithoutActivating"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideWindow(shouldActivatePreviousApp: false)
            }
        }
        
        // 监听热键变化
        NotificationCenter.default.addObserver(
            forName: .hotKeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateGlobalHotkey()
            }
        }
    }
    
    private func handleHotKeyPressed() {
        DispatchQueue.main.async { [weak self] in
            self?.toggleWindow()
        }
    }
    
    private func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    private func showWindow() {
        guard let window = window else { return }
        
        // 重置隐藏窗口标志
        isHidingWindow = false
        
        centerWindow()
        viewModel?.clearSearch()
        
        // 切换到英文输入法
        inputMethodManager.switchToEnglish()
        
        // 激活应用并显示窗口
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // 设置窗口为主要响应者，然后焦点会自动传递到文本框
        window.makeFirstResponder(window.contentView)
    }
     // 更新全局热键
    private func updateGlobalHotkey() {
        // 先注销旧的热键
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        if let modifierMonitor = modifierMonitor {
            NSEvent.removeMonitor(modifierMonitor)
            self.modifierMonitor = nil
        }

        // 重新设置热键
        setupGlobalHotkey()

        // 更新状态栏工具提示
        statusItem?.button?.toolTip = "LightLauncher - \(configManager.getHotKeyDescription())"
    }
    
    // 显示设置窗口
    private func showSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingView = NSHostingView(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "LightLauncher 设置"
            settingsWindow?.contentView = hostingView
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.level = .floating
            
            // 居中显示
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = settingsWindow!.frame
                let x = screenFrame.midX - windowFrame.width / 2
                let y = screenFrame.midY - windowFrame.height / 2
                settingsWindow?.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideWindow() {
        hideWindow(shouldActivatePreviousApp: true)
    }
    
    private func hideWindow(shouldActivatePreviousApp: Bool) {
        // 防止重复调用
        if isHidingWindow { return }
        isHidingWindow = true
        
        window?.orderOut(nil)
        viewModel?.clearSearch()
        
        // 恢复之前的输入法
        inputMethodManager.restorePreviousInputMethod()
        
        // 只有在明确要求激活前一个应用，且使用单独修饰键热键时，才执行应用切换逻辑
        if shouldActivatePreviousApp && settingsManager.hotKeyCode == 0 {
            // 将应用设置为非活跃状态，但不隐藏应用本身
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let frontmostApp = NSWorkspace.shared.frontmostApplication,
                   frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                    // 如果有其他应用在前台，就激活它
                    frontmostApp.activate(options: [])
                } else {
                    // 否则激活 Finder
                    if let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
                        NSWorkspace.shared.openApplication(at: finderURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                    }
                }
                
                // 重置标志
                Task { @MainActor in
                    self.isHidingWindow = false
                }
            }
        } else {
            // 重置标志
            DispatchQueue.main.async {
                self.isHidingWindow = false
            }
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // 设置图标 - 使用系统图标或自定义图标
            if let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "LightLauncher") {
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "🚀"
            }
            
            button.toolTip = "LightLauncher - \(settingsManager.getHotKeyDescription())"
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "显示启动器", action: #selector(showLauncher), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func showLauncher() {
        showWindow()
    }
    
    @objc private func openSettings() {
        showSettingsWindow()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "关于 LightLauncher"
        alert.informativeText = """
        LightLauncher 是一个快速的应用启动器
        
        版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        构建: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
        
        快捷键: \(settingsManager.getHotKeyDescription())
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        // Cleanup will be handled when the app terminates
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hideWindow()
    }
}

// MARK: - KeyHandlingView
class KeyHandlingView: NSHostingView<LauncherView> {
    private let viewModel: LauncherViewModel
    
    init(rootView: LauncherView, viewModel: LauncherViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        self.wantsLayer = true
    }
    
    required init(rootView: LauncherView) {
        fatalError("Use init(rootView:viewModel:) instead")
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

// MARK: - String Extension for FourCharCode
extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { bytes in
                for i in 0..<min(4, data.count) {
                    result = result << 8 + FourCharCode(bytes[i])
                }
            }
        }
        return result
    }
}

class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}
