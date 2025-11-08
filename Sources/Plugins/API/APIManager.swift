import AppKit
import Foundation
@preconcurrency import JavaScriptCore
import UserNotifications

/// 插件 API 管理器 - 为插件提供与主程序交互的 API
@MainActor
class APIManager {
    weak var pluginInstance: PluginInstance?
    private let permissionManager = PluginPermissionManager.shared
    private var pluginAPI: PluginAPI?

    init(pluginInstance: PluginInstance) {
        self.pluginInstance = pluginInstance
        self.pluginAPI = PluginAPI(
            pluginInstance: pluginInstance, permissionManager: permissionManager)
    }

    /// 将 API 注入到 JavaScript 上下文
    func injectAPIs(into context: JSContext) {
        guard let pluginInstance = pluginInstance else { return }

        // 创建 lightlauncher 全局对象
        let lightlauncher = JSValue(newObjectIn: context)
        context.setObject(lightlauncher, forKeyedSubscript: "lightlauncher" as NSString)

        // 注入核心 API
        injectCoreAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)

        // 注入文件 API
        injectFileAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)

        // 注入剪贴板 API
        injectClipboardAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)

        // 注入网络 API
        injectNetworkAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)

        // 注入系统 API
        injectSystemAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)

        // 注入权限 API
        injectPermissionAPIs(
            lightlauncher: lightlauncher, context: context, pluginInstance: pluginInstance)
    }

    // MARK: - 核心 API

    private func injectCoreAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // 显示结果
        let displayBlock: @convention(block) (JSValue?) -> Void = { [weak self] items in
            Task { @MainActor in
                self?.pluginAPI?.handleDisplayItems(items)
            }
        }
        lightlauncher?.setObject(displayBlock, forKeyedSubscript: "display" as NSString)

        // 日志输出
        let logBlock: @convention(block) (String) -> Void = { message in
            Logger.shared.info(
                "[Plugin \(pluginInstance.plugin.name)]: \(message)", owner: pluginInstance)
        }
        lightlauncher?.setObject(logBlock, forKeyedSubscript: "log" as NSString)

        // 注册回调
        let registerCallbackBlock: @convention(block) (JSValue?) -> Void = { callback in
            pluginInstance.searchCallback = callback
        }
        lightlauncher?.setObject(
            registerCallbackBlock, forKeyedSubscript: "registerCallback" as NSString)

        // 注册动作处理器
        let registerActionHandlerBlock: @convention(block) (JSValue?) -> Void = { handler in
            pluginInstance.actionHandler = handler
        }
        lightlauncher?.setObject(
            registerActionHandlerBlock, forKeyedSubscript: "registerActionHandler" as NSString)

        // 获取插件数据目录
        let getDataPathBlock: @convention(block) () -> String = { [weak self] in
            return self?.pluginAPI?.getPluginDataPath() ?? ""
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

    private func injectFileAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // 读取文件
        let readFileBlock: @convention(block) (String) -> String? = { [weak self] path in
            return self?.pluginAPI?.readFile(path: path)
        }
        lightlauncher?.setObject(readFileBlock, forKeyedSubscript: "readFile" as NSString)

        // 写入文件（接受 JSValue，内部做安全转换以避免桥接异常）
        let writeFileBlock: @convention(block) (JSValue?) -> Bool = { [weak self] paramsJS in
            guard let strong = self else { return false }
            guard let dict = strong.pluginAPI?.jsDictionary(from: paramsJS, in: context) else {
                return false
            }
            guard let path = dict["path"] as? String, let content = dict["content"] as? String
            else { return false }
            return strong.pluginAPI?.writeFile(path: path, content: content) ?? false
        }
        lightlauncher?.setObject(writeFileBlock, forKeyedSubscript: "writeFile" as NSString)
    }

    // MARK: - 剪贴板 API

    private func injectClipboardAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // 读取剪贴板
        let readClipboardBlock: @convention(block) () -> String? = { [weak self] in
            return self?.pluginAPI?.readClipboard()
        }
        lightlauncher?.setObject(readClipboardBlock, forKeyedSubscript: "readClipboard" as NSString)

        // 写入剪贴板
        let writeClipboardBlock: @convention(block) (String) -> Bool = { [weak self] text in
            return self?.pluginAPI?.writeClipboard(text: text) ?? false
        }
        lightlauncher?.setObject(
            writeClipboardBlock, forKeyedSubscript: "writeClipboard" as NSString)
    }

    // MARK: - 网络 API

    private func injectNetworkAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // HTTP 请求（接受 JSValue 参数，内部安全转换）
        let networkRequestBlock: @convention(block) (JSValue?, JSValue?) -> Void = {
            [weak self] paramsJS, callback in
            self?.pluginAPI?.makeNetworkRequest(
                paramsJS: paramsJS, callback: callback, context: context)
        }
        lightlauncher?.setObject(
            networkRequestBlock, forKeyedSubscript: "networkRequest" as NSString)
    }

    // MARK: - 系统 API

    private func injectSystemAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // 执行系统命令
        let executeCommandBlock: @convention(block) (String) -> [String: Any] = {
            [weak self] command in
            return self?.pluginAPI?.executeSystemCommand(command: command) ?? [
                "error": "API not available"
            ]
        }
        lightlauncher?.setObject(
            executeCommandBlock, forKeyedSubscript: "executeCommand" as NSString)

        // 显示通知
        let showNotificationBlock: @convention(block) (JSValue?) -> Bool = { [weak self] paramsJS in
            guard let strong = self else { return false }
            let params = strong.pluginAPI?.jsDictionary(from: paramsJS, in: context)
            return strong.pluginAPI?.showNotification(params: params) ?? false
        }
        lightlauncher?.setObject(
            showNotificationBlock, forKeyedSubscript: "showNotification" as NSString)
    }

    // MARK: - 权限 API

    private func injectPermissionAPIs(
        lightlauncher: JSValue?, context: JSContext, pluginInstance: PluginInstance
    ) {
        // 检查文件写入权限
        let hasFileWritePermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(
                plugin: pluginInstance.plugin, type: .fileWrite) ?? false
        }
        lightlauncher?.setObject(
            hasFileWritePermissionBlock, forKeyedSubscript: "hasFileWritePermission" as NSString)

        // 检查网络权限
        let hasNetworkPermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(
                plugin: pluginInstance.plugin, type: .network) ?? false
        }
        lightlauncher?.setObject(
            hasNetworkPermissionBlock, forKeyedSubscript: "hasNetworkPermission" as NSString)

        // 检查剪贴板权限
        let hasClipboardPermissionBlock: @convention(block) () -> Bool = { [weak self] in
            return self?.permissionManager.hasPermission(
                plugin: pluginInstance.plugin, type: .clipboard) ?? false
        }
        lightlauncher?.setObject(
            hasClipboardPermissionBlock, forKeyedSubscript: "hasClipboardPermission" as NSString)
    }

    // API 的具体实现已移动到 PluginAPI，APIManager 作为注入/委托层保留简洁接口。
}
