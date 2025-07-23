import Foundation
@preconcurrency import JavaScriptCore
import AppKit
import UserNotifications

/// 插件 API 管理器 - 为插件提供与主程序交互的 API
@MainActor
class APIManager {
    weak var pluginInstance: PluginInstance?
    private let permissionManager = PluginPermissionManager.shared
    
    init(pluginInstance: PluginInstance) {
        self.pluginInstance = pluginInstance
    }
    
    /// 将 API 注入到 JavaScript 上下文
    func injectAPIs(into context: JSContext) {
        guard let pluginInstance = pluginInstance else { return }
        
        // 创建 lightlauncher 全局对象
        let lightlauncher = JSValue(newObjectIn: context)
        context.setObject(lightlauncher, forKeyedSubscript: "lightlauncher" as NSString)
        
        // 注入核心 API
        injectCoreAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
        
        // 注入文件 API
        injectFileAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
        
        // 注入剪贴板 API
        injectClipboardAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
        
        // 注入网络 API
        injectNetworkAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
        
        // 注入系统 API
        injectSystemAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
        
        // 注入权限 API
        injectPermissionAPIs(lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
    }
    
    // MARK: - 核心 API
    
    private func injectCoreAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // 显示结果
        let displayBlock: @convention(block) (JSValue?) -> Void = { [weak self] items in
            Task { @MainActor in
                self?.handleDisplayItems(items, pluginInstance: pluginInstance)
            }
        }
        lightlauncher?.setObject(displayBlock, forKeyedSubscript: "display" as NSString)
        
        // 日志输出
        let logBlock: @convention(block) (String) -> Void = { message in
            print("[Plugin \(pluginInstance.plugin.name)]: \(message)")
        }
        lightlauncher?.setObject(logBlock, forKeyedSubscript: "log" as NSString)
        
        // 注册回调
        let registerCallbackBlock: @convention(block) (JSValue?) -> Void = { callback in
            pluginInstance.searchCallback = callback
        }
        lightlauncher?.setObject(registerCallbackBlock, forKeyedSubscript: "registerCallback" as NSString)
        
        // 注册动作处理器
        let registerActionHandlerBlock: @convention(block) (JSValue?) -> Void = { handler in
            pluginInstance.actionHandler = handler
        }
        lightlauncher?.setObject(registerActionHandlerBlock, forKeyedSubscript: "registerActionHandler" as NSString)
        
        // 获取插件数据目录
        let getDataPathBlock: @convention(block) () -> String = { [weak self] in
            return self?.getPluginDataPath(for: pluginInstance.plugin) ?? ""
        }
        lightlauncher?.setObject(getDataPathBlock, forKeyedSubscript: "getDataPath" as NSString)
        
        // 获取插件配置
        let getConfigBlock: @convention(block) () -> [String: Any] = {
            return pluginInstance.plugin.effectiveConfig
        }
        lightlauncher?.setObject(getConfigBlock, forKeyedSubscript: "getConfig" as NSString)

        // 刷新视图
        let refreshBlock: @convention(block) () -> Void = {
            pluginInstance.onItemsUpdated?()
            // PluginModeController.shared.updateDisplayableItems(from: pluginInstance)
            // LauncherViewModel.shared.forceRefresh = !LauncherViewModel.shared.forceRefresh
        }
        lightlauncher?.setObject(refreshBlock, forKeyedSubscript: "refresh" as NSString)
    }
    
    // MARK: - 文件 API
    
    private func injectFileAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // 读取文件
        let readFileBlock: @convention(block) (String) -> String? = { [weak self] path in
            return self?.readFile(path: path, pluginInstance: pluginInstance)
        }
        lightlauncher?.setObject(readFileBlock, forKeyedSubscript: "readFile" as NSString)
        
        // 写入文件
        let writeFileBlock: @convention(block) ([String: Any]) -> Bool = { [weak self] params in
            guard let path = params["path"] as? String,
                  let content = params["content"] as? String else {
                return false
            }
            return self?.writeFile(path: path, content: content, pluginInstance: pluginInstance) ?? false
        }
        lightlauncher?.setObject(writeFileBlock, forKeyedSubscript: "writeFile" as NSString)
    }
    
    // MARK: - 剪贴板 API
    
    private func injectClipboardAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // 读取剪贴板
        let readClipboardBlock: @convention(block) () -> String? = { [weak self] in
            return self?.readClipboard(pluginInstance: pluginInstance)
        }
        lightlauncher?.setObject(readClipboardBlock, forKeyedSubscript: "readClipboard" as NSString)
        
        // 写入剪贴板
        let writeClipboardBlock: @convention(block) (String) -> Bool = { [weak self] text in
            return self?.writeClipboard(text: text, pluginInstance: pluginInstance) ?? false
        }
        lightlauncher?.setObject(writeClipboardBlock, forKeyedSubscript: "writeClipboard" as NSString)
    }
    
    // MARK: - 网络 API
    
    private func injectNetworkAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // HTTP 请求
        let networkRequestBlock: @convention(block) ([String: Any], JSValue?) -> Void = { [weak self] params, callback in
            self?.makeNetworkRequest(params: params, callback: callback, pluginInstance: pluginInstance)
        }
        lightlauncher?.setObject(networkRequestBlock, forKeyedSubscript: "networkRequest" as NSString)
    }
    
    // MARK: - 系统 API
    
    private func injectSystemAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // 执行系统命令
        let executeCommandBlock: @convention(block) (String) -> [String: Any] = { [weak self] command in
            return self?.executeSystemCommand(command: command, pluginInstance: pluginInstance) ?? ["error": "API not available"]
        }
        lightlauncher?.setObject(executeCommandBlock, forKeyedSubscript: "executeCommand" as NSString)
        
        // 显示通知
        let showNotificationBlock: @convention(block) ([String: Any]) -> Bool = { [weak self] params in
            return self?.showNotification(params: params, pluginInstance: pluginInstance) ?? false
        }
        lightlauncher?.setObject(showNotificationBlock, forKeyedSubscript: "showNotification" as NSString)
    }
    
    // MARK: - 权限 API
    
    private func injectPermissionAPIs(lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance) {
        // 检查文件写入权限
        let hasFileWritePermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .fileWrite) ?? false
        }
        lightlauncher?.setObject(hasFileWritePermissionBlock, forKeyedSubscript: "hasFileWritePermission" as NSString)
        
        // 检查网络权限
        let hasNetworkPermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .network) ?? false
        }
        lightlauncher?.setObject(hasNetworkPermissionBlock, forKeyedSubscript: "hasNetworkPermission" as NSString)
        
        // 检查剪贴板权限
        let hasClipboardPermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .clipboard) ?? false
        }
        lightlauncher?.setObject(hasClipboardPermissionBlock, forKeyedSubscript: "hasClipboardPermission" as NSString)
    }
    
    // MARK: - API 实现
    
    private func handleDisplayItems(_ items: JSValue?, pluginInstance: PluginInstance) {
        guard let items = items,
              let itemsArray = items.toArray() as? [[String: Any]] else {
            return
        }
        
        let pluginItems = itemsArray.compactMap { itemDict -> PluginItem? in
            guard let title = itemDict["title"] as? String else { return nil }
            
            let subtitle = itemDict["subtitle"] as? String
            let iconName = itemDict["icon"] as? String
            let action = itemDict["action"] as? String
            
            return PluginItem(title: title, subtitle: subtitle, iconName: iconName, action: action)
        }
        
        pluginInstance.currentItems = pluginItems
    }
    
    private func getPluginDataPath(for plugin: Plugin) -> String {
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let dataDir = homeDir.appendingPathComponent(".config/LightLauncher/data/\(plugin.name)")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        
        return dataDir.path
    }
    
    private func readFile(path: String, pluginInstance: PluginInstance) -> String? {
        // 检查权限
        if !isPathInPluginDataDirectory(path, plugin: pluginInstance.plugin) {
            guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .fileRead) else {
                print("插件 \(pluginInstance.plugin.name) 没有文件读取权限")
                return nil
            }
        }
        
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            print("读取文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func writeFile(path: String, content: String, pluginInstance: PluginInstance) -> Bool {
        // 检查权限
        if !isPathInPluginDataDirectory(path, plugin: pluginInstance.plugin) {
            guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .fileWrite) else {
                print("插件 \(pluginInstance.plugin.name) 没有文件写入权限")
                return false
            }
        }
        
        do {
            // 确保目录存在
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), 
                                                  withIntermediateDirectories: true)
            
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("写入文件失败: \(error.localizedDescription)")
            return false
        }
    }
    
    private func readClipboard(pluginInstance: PluginInstance) -> String? {
        guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .clipboard) else {
            print("插件 \(pluginInstance.plugin.name) 没有剪贴板权限")
            return nil
        }
        
        return NSPasteboard.general.string(forType: .string)
    }
    
    private func writeClipboard(text: String, pluginInstance: PluginInstance) -> Bool {
        guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .clipboard) else {
            print("插件 \(pluginInstance.plugin.name) 没有剪贴板权限")
            return false
        }
        
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func makeNetworkRequest(params: [String: Any], callback: JSValue?, pluginInstance: PluginInstance) {
        guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .network) else {
            print("插件 \(pluginInstance.plugin.name) 没有网络权限")
            return
        }
        
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            return
        }
        
        let method = params["method"] as? String ?? "GET"
        let headers = params["headers"] as? [String: String]
        let body = params["body"] as? String
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                var result: [String: Any] = [:]
                
                if let error = error {
                    result["error"] = error.localizedDescription
                } else {
                    if let data = data {
                        result["data"] = String(data: data, encoding: .utf8) ?? ""
                    }
                    if let httpResponse = response as? HTTPURLResponse {
                        result["status"] = httpResponse.statusCode
                        result["headers"] = httpResponse.allHeaderFields
                    }
                }
                
                callback?.call(withArguments: [result])
            }
        }.resume()
    }
    
    private func executeSystemCommand(command: String, pluginInstance: PluginInstance) -> [String: Any] {
        guard permissionManager.hasPermission(plugin: pluginInstance.plugin, type: .systemCommand) else {
            return ["error": "插件 \(pluginInstance.plugin.name) 没有系统命令权限"]
        }
        
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return [
                "exitCode": process.terminationStatus,
                "output": output
            ]
        } catch {
            return ["error": error.localizedDescription]
        }
    }
    
    private func showNotification(params: [String: Any], pluginInstance: PluginInstance) -> Bool {
        guard let title = params["title"] as? String else { return false }
        let subtitle = params["subtitle"] as? String
        let body = params["body"] as? String

        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle { content.subtitle = subtitle }
        if let body = body { content.body = body }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    private func isPathInPluginDataDirectory(_ path: String, plugin: Plugin) -> Bool {
        let pluginDataPath = getPluginDataPath(for: plugin)
        return path.hasPrefix(pluginDataPath)
    }
}