import AppKit
import Foundation
@preconcurrency import JavaScriptCore
import UserNotifications

/// 插件具体 API 实现，供 `APIManager` 委托调用，拆分以减少单一文件体积。
@MainActor
final class PluginAPI {
    private weak var pluginInstance: PluginInstance?
    private let permissionManager: PluginPermissionManager

    init(pluginInstance: PluginInstance, permissionManager: PluginPermissionManager) {
        self.pluginInstance = pluginInstance
        self.permissionManager = permissionManager
    }

    // 将 JSValue 安全转换为 Swift 字典（仅当 JSValue 表示对象时）
    func jsDictionary(from value: JSValue?, in context: JSContext?) -> [String: Any]? {
        guard let v = value else { return nil }
        if !v.isObject { return nil }
        return v.toDictionary() as? [String: Any]
    }

    func handleDisplayItems(_ items: JSValue?) {
        guard let pluginInstance = pluginInstance else { return }
        guard let items = items else { return }

        var itemsArray: [[String: Any]] = []

        if let ctx = pluginInstance.context {
            if let arrayConstructor = ctx.objectForKeyedSubscript("Array"),
                let isArrayFunc = arrayConstructor.objectForKeyedSubscript("isArray")
            {
                let isArray = isArrayFunc.call(withArguments: [items])?.toBool() ?? false
                if isArray {
                    if let arr = items.toArray() {
                        for elem in arr {
                            if let dict = elem as? [String: Any] {
                                itemsArray.append(dict)
                            }
                        }
                    }
                } else {
                    if items.isObject, let dict = items.toDictionary() as? [String: Any] {
                        itemsArray = [dict]
                    } else {
                        return
                    }
                }
            } else {
                if items.isObject, let dict = items.toDictionary() as? [String: Any] {
                    itemsArray = [dict]
                } else if let arr = items.toArray() {
                    for elem in arr {
                        if let dict = elem as? [String: Any] {
                            itemsArray.append(dict)
                        }
                    }
                } else {
                    return
                }
            }
        } else {
            if items.isObject, let dict = items.toDictionary() as? [String: Any] {
                itemsArray = [dict]
            } else if let arr = items.toArray() {
                for elem in arr {
                    if let dict = elem as? [String: Any] {
                        itemsArray.append(dict)
                    }
                }
            } else {
                return
            }
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

    // MARK: - Data path helpers
    func getPluginDataPath() -> String {
        guard let plugin = pluginInstance?.plugin else { return "" }
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let dataDir = homeDir.appendingPathComponent(".config/LightLauncher/data/\(plugin.name)")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir.path
    }

    func isPathInPluginDataDirectory(_ path: String) -> Bool {
        let pluginDataPath = getPluginDataPath()
        return path.hasPrefix(pluginDataPath)
    }

    // MARK: - File APIs
    func readFile(path: String) -> String? {
        guard let plugin = pluginInstance?.plugin else { return nil }
        if !isPathInPluginDataDirectory(path) {
            guard permissionManager.hasPermission(plugin: plugin, type: .fileRead) else {
                print("插件 \(plugin.name) 没有文件读取权限")
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

    func writeFile(path: String, content: String) -> Bool {
        guard let plugin = pluginInstance?.plugin else { return false }
        if !isPathInPluginDataDirectory(path) {
            guard permissionManager.hasPermission(plugin: plugin, type: .fileWrite) else {
                print("插件 \(plugin.name) 没有文件写入权限")
                return false
            }
        }

        if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }

        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            return false
        }

        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            guard let data = content.data(using: .utf8) else { return false }
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("写入文件失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Clipboard APIs
    func readClipboard() -> String? {
        guard let plugin = pluginInstance?.plugin else { return nil }
        guard permissionManager.hasPermission(plugin: plugin, type: .clipboard) else {
            print("插件 \(plugin.name) 没有剪贴板权限")
            return nil
        }
        return NSPasteboard.general.string(forType: .string)
    }

    func writeClipboard(text: String) -> Bool {
        guard let plugin = pluginInstance?.plugin else { return false }
        guard permissionManager.hasPermission(plugin: plugin, type: .clipboard) else {
            print("插件 \(plugin.name) 没有剪贴板权限")
            return false
        }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Network API
    func makeNetworkRequest(paramsJS: JSValue?, callback: JSValue?, context: JSContext) {
        guard let plugin = pluginInstance?.plugin else { return }
        guard permissionManager.hasPermission(plugin: plugin, type: .network) else {
            print("插件 \(plugin.name) 没有网络权限")
            return
        }

        guard let params = jsDictionary(from: paramsJS, in: context) else { return }
        guard let urlString = params["url"] as? String, let url = URL(string: urlString) else {
            return
        }

        let method = params["method"] as? String ?? "GET"
        let headers = params["headers"] as? [String: String]
        let body = params["body"] as? String

        var request = URLRequest(url: url)
        request.httpMethod = method
        headers?.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }
        if let body = body { request.httpBody = body.data(using: .utf8) }

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

    // MARK: - System APIs
    func executeSystemCommand(command: String) -> [String: Any] {
        guard let plugin = pluginInstance?.plugin else { return ["error": "no plugin"] }
        guard permissionManager.hasPermission(plugin: plugin, type: .systemCommand) else {
            return ["error": "插件 \(plugin.name) 没有系统命令权限"]
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
            return ["exitCode": process.terminationStatus, "output": output]
        } catch {
            return ["error": error.localizedDescription]
        }
    }

    func showNotification(params: [String: Any]?) -> Bool {
        guard let params = params, let title = params["title"] as? String else { return false }
        let subtitle = params["subtitle"] as? String
        let body = params["body"] as? String

        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle { content.subtitle = subtitle }
        if let body = body { content.body = body }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error { print("通知发送失败: \(error.localizedDescription)") }
        }
        return true
    }
}
