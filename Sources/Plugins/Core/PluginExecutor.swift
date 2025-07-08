import Foundation
import JavaScriptCore

/// 插件执行器 - 负责在JavaScript环境中执行插件脚本
@MainActor
class PluginExecutor {
    static let shared = PluginExecutor()
    
    private let context: JSContext
    
    private init() {
        self.context = JSContext()!
        setupJavaScriptEnvironment()
    }
    
    /// 设置JavaScript执行环境
    private func setupJavaScriptEnvironment() {
        // 设置异常处理
        context.exceptionHandler = { context, exception in
            if let exception = exception {
                print("JavaScript执行错误: \(exception)")
            }
        }
        
        // 注入console对象
        let console = JSValue(newObjectIn: context)!
        console.setObject(unsafeBitCast({ (message: String) in
            print("[Plugin Console] \(message)")
        } as @convention(block) (String) -> Void, to: AnyObject.self), forKeyedSubscript: "log" as NSString)
        
        context.setObject(console, forKeyedSubscript: "console" as NSString)
        
        // 注入API对象
        setupPluginAPI()
    }
    
    /// 设置插件API
    private func setupPluginAPI() {
        let api = JSValue(newObjectIn: context)!
        
        // 添加获取输入文本的API
        api.setObject(unsafeBitCast({ () -> String in
            // 这里应该从实际的输入源获取文本
            // 暂时返回空字符串
            return ""
        } as @convention(block) () -> String, to: AnyObject.self), forKeyedSubscript: "getInputText" as NSString)
        
        // 添加设置输出文本的API
        api.setObject(unsafeBitCast({ (text: String) in
            // 这里应该将文本输出到实际的目标
            print("[Plugin Output] \(text)")
        } as @convention(block) (String) -> Void, to: AnyObject.self), forKeyedSubscript: "setOutputText" as NSString)
        
        context.setObject(api, forKeyedSubscript: "api" as NSString)
    }
    
    /// 执行插件
    func execute(plugin: Plugin, with arguments: [String] = []) async throws -> PluginExecutionResult {
        // 重新创建JavaScript执行环境
        setupJavaScriptEnvironment()
        
        // 设置插件的全局变量
        context.setObject(plugin.script, forKeyedSubscript: "pluginScript" as NSString)
        
        // 执行插件脚本
        let result = context.evaluateScript(plugin.script)
        
        // 检查执行结果
        if let error = context.exception {
            throw PluginError.scriptEvaluationFailed(error.toString())
        }
        
        return PluginExecutionResult(success: true, output: result?.toString() ?? "")
    }
    
    /// 注入视图模型
    func injectViewModel(_ viewModel: LauncherViewModel, for command: String) {
        // 实现视图模型注入逻辑
        print("注入视图模型到插件: \(command)")
    }
    
    /// 执行插件搜索（带命令）
    func executePluginSearch(command: String, query: String) throws {
        print("执行插件搜索: \(command), 查询: \(query)")
        // 实现插件搜索逻辑
    }
    
    /// 执行插件搜索（带插件对象）
    func executePluginSearch(plugin: Plugin, query: String) throws {
        print("执行插件搜索: \(plugin.name), 查询: \(query)")
        // 实现插件搜索逻辑
    }
    
    /// 执行插件动作
    func executePluginAction(command: String, action: String) -> Bool {
        print("执行插件动作: \(command), 动作: \(action)")
        // 实现插件动作执行逻辑
        return true
    }
    
    /// 清理插件
    func cleanupPlugin(command: String) async {
        print("清理插件: \(command)")
        // 实现插件清理逻辑
    }
}

/// 插件执行结果
struct PluginExecutionResult {
    let success: Bool
    let output: String
}
