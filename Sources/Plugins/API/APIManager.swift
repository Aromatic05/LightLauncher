import Foundation
import JavaScriptCore
import os

// MARK: - 插件 API 管理器
class APIManager: NSObject, PluginAPIExports, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "APIManager")
    
    // MARK: - 属性
    weak var viewModel: LauncherViewModel?
    weak var pluginContext: JSContext?
    
    // 存储插件注册的回调函数
    private var searchCallback: JSValue?
    
    // MARK: - 初始化
    init(viewModel: LauncherViewModel?, context: JSContext?) {
        self.viewModel = viewModel
        self.pluginContext = context
        super.init()
    }
    
    // MARK: - PluginAPIExports 实现
    
    func registerCallback(_ function: JSValue) {
        guard function.isObject, !function.isUndefined else {
            logger.error("Invalid callback function provided to registerCallback")
            return
        }
        
        searchCallback = function
        logger.debug("Plugin callback function registered successfully")
    }
    
    func display(_ results: [[String: Any]]) {
        logger.debug("Displaying \(results.count) results from plugin")
        
        // 转换字典数组为 PluginItem 数组
        let pluginItems = results.compactMap { resultDict -> PluginItem? in
            guard let title = resultDict["title"] as? String else {
                logger.warning("Result missing required 'title' field")
                return nil
            }
            
            let subtitle = resultDict["subtitle"] as? String ?? ""
            let icon = resultDict["icon"] as? String ?? "questionmark.circle"
            let action = resultDict["action"] as? String
            
            return PluginItem(
                title: title,
                subtitle: subtitle,
                icon: icon,
                action: action
            )
        }
        
        // 在主线程更新 ViewModel
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.updatePluginResults(pluginItems)
        }
    }
    
    func hide() {
        logger.debug("Plugin requested to hide launcher window")
        
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.hideLauncher()
        }
    }
    
    func log(_ message: String) {
        logger.info("Plugin Log: \(message)")
        print("[Plugin] \(message)") // 同时输出到控制台便于调试
    }
    
    // MARK: - 公开方法
    
    /// 调用插件的搜索回调函数
    func invokeSearchCallback(with query: String) {
        guard let callback = searchCallback,
              let context = pluginContext else {
            logger.warning("No search callback or context available")
            return
        }
        
        logger.debug("Invoking plugin search callback with query: \(query)")
        
        // 在 JavaScript 上下文中调用回调函数
        let result = callback.call(withArguments: [query])
        
        if let error = context.exception {
            logger.error("JavaScript callback execution error: \(error)")
            context.exception = nil // 清除异常
        } else if let result = result, !result.isUndefined {
            logger.debug("Plugin callback executed successfully")
        }
    }
    
    /// 清理资源
    func cleanup() {
        searchCallback = nil
        viewModel = nil
        pluginContext = nil
        logger.debug("APIManager cleaned up")
    }
}
