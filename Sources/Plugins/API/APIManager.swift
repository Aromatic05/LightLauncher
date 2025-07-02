import Foundation
import JavaScriptCore
import os

// MARK: - 插件 API 管理器
class APIManager: NSObject, PluginAPIExports, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.lightlauncher.plugins", category: "APIManager")
    
    // MARK: - 属性
    weak var viewModel: LauncherViewModel?
    weak var pluginContext: JSContext?
    
    // 插件标识信息
    private let pluginName: String
    private let pluginCommand: String
    
    // 存储插件注册的回调函数
    private var searchCallback: JSValue?
    private var actionHandler: JSValue?
    
    // 文件路径
    private let configsDirectory: URL
    private let dataDirectory: URL
    
    // MARK: - 初始化
    init(viewModel: LauncherViewModel?, context: JSContext?, pluginName: String = "", pluginCommand: String = "") {
        self.viewModel = viewModel
        self.pluginContext = context
        self.pluginName = pluginName
        self.pluginCommand = pluginCommand
        
        // 设置配置和数据目录路径
        let lightLauncherConfigDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        
        self.configsDirectory = lightLauncherConfigDir.appendingPathComponent("configs")
        self.dataDirectory = lightLauncherConfigDir.appendingPathComponent("data")
        
        super.init()
        
        // 确保目录存在
        createDirectoriesIfNeeded()
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
    
    func registerActionHandler(_ function: JSValue) {
        guard function.isObject, !function.isUndefined else {
            logger.error("Invalid action handler function provided to registerActionHandler")
            return
        }
        
        actionHandler = function
        logger.debug("Plugin action handler registered successfully")
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
    
    /// 调用插件的动作处理函数
    func invokeActionHandler(with action: String) -> Bool {
        guard let handler = actionHandler,
              let context = pluginContext else {
            logger.warning("No action handler or context available")
            return false
        }
        
        logger.debug("Invoking plugin action handler with action: \(action)")
        
        // 在 JavaScript 上下文中调用动作处理函数
        let result = handler.call(withArguments: [action])
        
        if let error = context.exception {
            logger.error("JavaScript action handler execution error: \(error)")
            context.exception = nil // 清除异常
            return false
        }
        
        if let result = result {
            logger.debug("Plugin action handler executed successfully")
            // 如果返回值是布尔类型，使用其值；否则默认为 true
            return result.toBool()
        }
        
        return true
    }
    
    /// 清理资源
    func cleanup() {
        searchCallback = nil
        actionHandler = nil
        viewModel = nil
        pluginContext = nil
        logger.debug("APIManager cleaned up")
    }
    
    // MARK: - 文件系统 API 实现
    
    func getConfigPath() -> String {
        let configFileName = pluginName.isEmpty ? "default.yaml" : "\(pluginName).yaml"
        return configsDirectory.appendingPathComponent(configFileName).path
    }
    
    func getDataPath() -> String {
        let dataDirectoryName = pluginName.isEmpty ? "default" : pluginName
        return dataDirectory.appendingPathComponent(dataDirectoryName).path
    }
    
    func readConfig() -> String? {
        let configPath = getConfigPath()
        return readFile(configPath)
    }
    
    func writeConfig(_ content: String) -> Bool {
        let configPath = getConfigPath()
        return writeFile(configPath, content: content)
    }
    
    func fileExists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    func readFile(_ path: String) -> String? {
        guard isPathSafe(path) else {
            logger.error("Unsafe path access attempted: \(path)")
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            logger.debug("Successfully read file: \(path)")
            return content
        } catch {
            logger.error("Failed to read file \(path): \(error.localizedDescription)")
            return nil
        }
    }
    
    func writeFile(_ path: String, content: String) -> Bool {
        guard isPathSafe(path) else {
            logger.error("Unsafe path access attempted: \(path)")
            return false
        }
        
        do {
            // 确保父目录存在
            let fileURL = URL(fileURLWithPath: path)
            let parentDirectory = fileURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                try FileManager.default.createDirectory(at: parentDirectory, 
                                                       withIntermediateDirectories: true, 
                                                       attributes: nil)
            }
            
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            logger.debug("Successfully wrote file: \(path)")
            return true
        } catch {
            logger.error("Failed to write file \(path): \(error.localizedDescription)")
            return false
        }
    }
    
    func createDirectory(_ path: String) -> Bool {
        guard isPathSafe(path) else {
            logger.error("Unsafe path access attempted: \(path)")
            return false
        }
        
        do {
            try FileManager.default.createDirectory(atPath: path, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
            logger.debug("Successfully created directory: \(path)")
            return true
        } catch {
            logger.error("Failed to create directory \(path): \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 私有辅助方法
    
    /// 创建必要的目录
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        
        // 创建 configs 目录
        if !fileManager.fileExists(atPath: self.configsDirectory.path) {
            do {
                try fileManager.createDirectory(at: self.configsDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
                logger.info("Created configs directory at: \(self.configsDirectory.path)")
            } catch {
                logger.error("Failed to create configs directory: \(error.localizedDescription)")
            }
        }
        
        // 创建 data 目录
        if !fileManager.fileExists(atPath: self.dataDirectory.path) {
            do {
                try fileManager.createDirectory(at: self.dataDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
                logger.info("Created data directory at: \(self.dataDirectory.path)")
            } catch {
                logger.error("Failed to create data directory: \(error.localizedDescription)")
            }
        }
        
        // 为当前插件创建专用数据目录
        if !pluginName.isEmpty {
            let pluginDataPath = self.dataDirectory.appendingPathComponent(pluginName)
            if !fileManager.fileExists(atPath: pluginDataPath.path) {
                do {
                    try fileManager.createDirectory(at: pluginDataPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
                    logger.info("Created plugin data directory at: \(pluginDataPath.path)")
                } catch {
                    logger.error("Failed to create plugin data directory: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 检查路径是否安全（防止路径遍历攻击）
    private func isPathSafe(_ path: String) -> Bool {
        let lightLauncherDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/LightLauncher")
        
        let resolvedPath = URL(fileURLWithPath: path).standardized.path
        let allowedPath = lightLauncherDir.standardized.path
        
        return resolvedPath.hasPrefix(allowedPath)
    }
}