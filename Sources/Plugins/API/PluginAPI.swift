import Foundation
import JavaScriptCore
import AppKit

/// 定义插件API的协议，用于JavaScriptCore绑定
@objc protocol PluginAPIExports: JSExport {
    // 系统接口
    func log(_ message: String)
    func showNotification(_ title: String, _ message: String)
    
    // 文件操作
    func readFile(_ path: String) -> String?
    func writeFile(_ path: String, _ content: String) -> Bool
    func fileExists(_ path: String) -> Bool
    
    // 剪贴板操作
    func getClipboard() -> String
    func setClipboard(_ text: String)
    
    // UI 交互
    func showInput(_ prompt: String) -> String?
    func showAlert(_ message: String)
    func updateUI(_ data: [String: Any])
}

/// 插件API实现类
@objc class PluginAPI: NSObject, PluginAPIExports {
    private let plugin: Plugin
    
    init(plugin: Plugin) {
        self.plugin = plugin
        super.init()
    }
    
    // MARK: - 系统接口
    func log(_ message: String) {
        print("[Plugin \(plugin.name)] \(message)")
    }
    
    func showNotification(_ title: String, _ message: String) {
        // 调度到主线程执行
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = message
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    // MARK: - 文件操作
    func readFile(_ path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            log("读取文件失败: \(error)")
            return nil
        }
    }
    
    func writeFile(_ path: String, _ content: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            log("写入文件失败: \(error)")
            return false
        }
    }
    
    func fileExists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    // MARK: - 剪贴板操作
    func getClipboard() -> String {
        var clipboardContent = ""
        // 调度到主线程执行
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
            semaphore.signal()
        }
        semaphore.wait()
        return clipboardContent
    }
    
    func setClipboard(_ text: String) {
        // 调度到主线程执行
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }
    
    // MARK: - UI 交互
    func showInput(_ prompt: String) -> String? {
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "取消")
            
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            alert.accessoryView = input
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                result = input.stringValue
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    func updateUI(_ userInfo: [String: Any]) {
        // 先序列化为 Data，闭包只捕获 Data，主线程内反序列化
        let data = try? JSONSerialization.data(withJSONObject: userInfo, options: [])
        DispatchQueue.main.async {
            var safeUserInfo: [String: Any] = [:]
            if let data = data,
               let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                safeUserInfo = dict
            }
            NotificationCenter.default.post(
                name: Notification.Name("PluginUIUpdate"),
                object: nil,
                userInfo: safeUserInfo
            )
        }
    }
}
