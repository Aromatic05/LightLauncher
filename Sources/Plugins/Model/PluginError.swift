import Foundation

/// 插件相关的错误类型
enum PluginError: Error, LocalizedError {
    case invalidManifest(String) // 需要传递错误信息
    case missingMainFile(String)
    case loadFailed(String)
    case executionFailed(String)
    case invalidConfiguration(String)
    case dependencyNotFound(String)
    case versionMismatch(String)
    case permissionDenied(String)
    case timeout(String)
    case invalidAPI(String)
    case missingScript(String)
    case invalidScript(String)
    case scriptEvaluationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidManifest(let message):
            return "插件清单文件无效: \(message)"
        case .missingMainFile(let path):
            return "找不到插件主文件: \(path)"
        case .loadFailed(let message):
            return "插件加载失败: \(message)"
        case .executionFailed(let message):
            return "插件执行失败: \(message)"
        case .invalidConfiguration(let message):
            return "插件配置无效: \(message)"
        case .dependencyNotFound(let dependency):
            return "找不到依赖: \(dependency)"
        case .versionMismatch(let message):
            return "版本不匹配: \(message)"
        case .permissionDenied(let message):
            return "权限被拒绝: \(message)"
        case .timeout(let message):
            return "操作超时: \(message)"
        case .invalidAPI(let message):
            return "无效的API调用: \(message)"
        case .missingScript(let message):
            return "缺少脚本: \(message)"
        case .invalidScript(let message):
            return "无效的脚本: \(message)"
        case .scriptEvaluationFailed(let message):
            return "脚本评估失败: \(message)"
        }
    }
}
