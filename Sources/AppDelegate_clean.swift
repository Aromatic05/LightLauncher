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
    private var appScanner = AppScanner()
    private var viewModel: LauncherViewModel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var inputMethodManager = InputMethodManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // No dock icon
        
        setupViewModel()
        setupWindow()
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
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyId,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            
            // Install a simple event handler
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
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .hideWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideWindow()
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
    
    private func hideWindow() {
        window?.orderOut(nil)
        viewModel?.clearSearch()
        
        // 恢复之前的输入法
        inputMethodManager.restorePreviousInputMethod()
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
