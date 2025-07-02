import Foundation
import JavaScriptCore

// MARK: - 插件 API 导出协议
@objc protocol PluginAPIExports: JSExport {
    /// 注册插件的回调函数，用于处理搜索请求
    func registerCallback(_ function: JSValue)
    
    /// 显示插件返回的搜索结果
    func display(_ results: [[String: Any]])
    
    /// 隐藏启动器窗口
    func hide()
    
    /// 记录日志信息到控制台
    func log(_ message: String)
}

// MARK: - 插件 API 错误
enum PluginAPIError: Error, LocalizedError {
    case invalidCallback
    case invalidResults
    case contextNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid callback function provided"
        case .invalidResults:
            return "Invalid results format"
        case .contextNotAvailable:
            return "JavaScript context not available"
        }
    }
}
