import JavaScriptCore
import Combine

// MARK: - 插件运行时实例

/// 管理一个活动插件的运行时状态和资源。
@MainActor
class PluginInstance {
    /// 引用插件的静态数据蓝图。
    let plugin: Plugin
    /// JavaScript 上下文，仅在插件被激活时创建。
    var context: JSContext?
    /// 为该实例创建的 API 管理器。
    var apiManager: APIManager?
    /// 该插件在当前会话中是否被用户启用。
    var isEnabled: Bool = true
    
    /// 搜索回调函数
    var searchCallback: JSValue?
    /// 动作处理器
    var actionHandler: JSValue?
    /// 当前显示的项目
    @Published var currentItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    var dataDidChange = PassthroughSubject<Void, Never>()

    /// items 更新时的通知回调，由主程序设置
    var onItemsUpdated: (() -> Void)?
    
    init(plugin: Plugin) {
        self.plugin = plugin
    }
    
    /// 处理输入
    /// - Parameter input: 用户输入
    func handleInput(_ input: String) {
        guard isEnabled, let callback = searchCallback else { return }
        
        callback.call(withArguments: [input])
    }
    
    /// 执行动作
    /// - Parameter action: 动作标识符
    /// - Returns: 是否成功执行
    func executeAction(_ action: String) -> Bool {
        guard isEnabled, let handler = actionHandler else { return false }
        
        let result = handler.call(withArguments: [action])
        return result?.toBool() ?? false
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
        self.searchCallback = nil
        self.actionHandler = nil
        self.currentItems.removeAll()
    }
}
