import JavaScriptCore

// MARK: - 插件运行时实例

/// 管理一个活动插件的运行时状态和资源。

class PluginInstance {
    /// 引用插件的静态数据蓝图。
    let plugin: Plugin
    /// JavaScript 上下文，仅在插件被激活时创建。
    var context: JSContext?
    /// 为该实例创建的 API 管理器。
    var apiManager: APIManager?
    /// 该插件在当前会话中是否被用户启用。
    var isEnabled: Bool = true
    init(plugin: Plugin) {

        self.plugin = plugin

    }
    /// 设置并准备 JS 环境。
    func setupContext() {
        guard context == nil else { return }
        print("为插件 '\(plugin.name)' 创建 JSContext...")
        self.context = JSContext()
        // ... 在这里注入 host 对象、配置等
        context?.evaluateScript(plugin.script)

    }

    /// 释放资源。

    func cleanup() {
        print("清理插件 '\(plugin.name)' 的资源...")
        self.context = nil
        self.apiManager = nil
    }
}
