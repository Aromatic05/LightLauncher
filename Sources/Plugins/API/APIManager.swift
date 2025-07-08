import Foundation
import JavaScriptCore

/// API管理器 - 负责为插件提供原生API接口
@MainActor
class APIManager {
    private let plugin: Plugin
    private let pluginAPI: PluginAPI
    
    init(plugin: Plugin) {
        self.plugin = plugin
        self.pluginAPI = PluginAPI(plugin: plugin)
    }
    
    /// 将API注入到JavaScript上下文中
    func injectAPI(into context: JSContext) {
        // 注入插件API对象
        context.setObject(pluginAPI, forKeyedSubscript: "api" as NSString)
        
        // 注入console对象
        let console = JSValue(newObjectIn: context)!
        console.setObject(unsafeBitCast({ (message: String) in
            self.pluginAPI.log(message)
        } as @convention(block) (String) -> Void, to: AnyObject.self), forKeyedSubscript: "log" as NSString)
        
        context.setObject(console, forKeyedSubscript: "console" as NSString)
        
        // 注入插件配置
        let config = JSValue(newObjectIn: context)!
        for (key, value) in plugin.effectiveConfig {
            config.setObject(value, forKeyedSubscript: key as NSString)
        }
        context.setObject(config, forKeyedSubscript: "config" as NSString)
        
        // 注入插件元信息
        let meta = JSValue(newObjectIn: context)!
        meta.setObject(plugin.name, forKeyedSubscript: "name" as NSString)
        meta.setObject(plugin.version, forKeyedSubscript: "version" as NSString)
        meta.setObject(plugin.description, forKeyedSubscript: "description" as NSString)
        context.setObject(meta, forKeyedSubscript: "meta" as NSString)
    }
    
    /// 清理API资源
    func cleanup() {
        // 目前没有需要清理的资源
    }
}
