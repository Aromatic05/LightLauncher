import Foundation
import JavaScriptCore

// MARK: - 插件 API 导出协议
@objc protocol PluginAPIExports: JSExport {
    /// 注册插件的回调函数，用于处理搜索请求
    func registerCallback(_ function: JSValue)
    
    /// 注册插件的动作处理函数
    func registerActionHandler(_ function: JSValue)
    
    /// 显示插件返回的搜索结果
    func display(_ results: [[String: Any]])
    
    /// 隐藏启动器窗口
    func hide()
    
    /// 记录日志信息到控制台
    func log(_ message: String)
    
    // MARK: - 文件系统 API
    
    /// 获取插件配置文件路径
    func getConfigPath() -> String
    
    /// 获取插件数据目录路径
    func getDataPath() -> String
    
    /// 读取配置文件内容
    func readConfig() -> String?
    
    /// 写入配置文件内容
    func writeConfig(_ content: String) -> Bool
    
    /// 检查文件是否存在
    func fileExists(_ path: String) -> Bool
    
    /// 读取文件内容
    func readFile(_ path: String) -> String?
    
    /// 写入文件内容
    func writeFile(_ data: [String: Any]) -> Bool
    
    /// 创建目录
    func createDirectory(_ path: String) -> Bool
}

// MARK: - 插件 API 错误
enum PluginAPIError: Error, LocalizedError {
    case invalidCallback
    case invalidActionHandler
    case invalidResults
    case contextNotAvailable
    case actionNotFound
    case fileOperationFailed(String)
    case configurationError(String)
    case pathAccessDenied(String)
    case networkAccessDenied
    case networkRequestFailed(String)
    case invalidURL(String)
    case permissionDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid callback function provided"
        case .invalidActionHandler:
            return "Invalid action handler function provided"
        case .invalidResults:
            return "Invalid results format"
        case .contextNotAvailable:
            return "JavaScript context not available"
        case .actionNotFound:
            return "Action not found in plugin"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        case .pathAccessDenied(let path):
            return "Access denied to path: \(path)"
        case .networkAccessDenied:
            return "Network access denied for this plugin"
        case .networkRequestFailed(let reason):
            return "Network request failed: \(reason)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        }
    }
}
