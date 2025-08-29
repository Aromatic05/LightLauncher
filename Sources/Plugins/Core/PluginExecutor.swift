import Foundation
import JavaScriptCore

/// 插件执行器 - 负责创建和管理插件实例
@MainActor
class PluginExecutor {
    static let shared = PluginExecutor()

    private var instances: [String: PluginInstance] = [:]

    private init() {}

    /// 创建插件实例
    /// - Parameter plugin: 插件对象
    /// - Returns: 插件实例，如果创建失败则返回 nil
    func createInstance(for plugin: Plugin) -> PluginInstance? {
        // 检查是否已存在实例
        if let existingInstance = instances[plugin.name] {
            return existingInstance
        }

        do {
            let instance = PluginInstance(plugin: plugin)
            try setupInstance(instance)

            instances[plugin.name] = instance
            print("插件实例已创建: \(plugin.name)")

            return instance
        } catch {
            print("创建插件实例失败 (\(plugin.name)): \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取插件实例
    /// - Parameter pluginName: 插件名称
    /// - Returns: 插件实例，如果不存在则返回 nil
    func getInstance(for pluginName: String) -> PluginInstance? {
        return instances[pluginName]
    }

    /// 销毁插件实例
    /// - Parameter pluginName: 插件名称
    func destroyInstance(for pluginName: String) {
        if let instance = instances.removeValue(forKey: pluginName) {
            instance.cleanup()
            print("插件实例已销毁: \(pluginName)")
        }
    }

    /// 销毁所有插件实例
    func destroyAllInstances() {
        for (name, instance) in instances {
            instance.cleanup()
            print("插件实例已销毁: \(name)")
        }
        instances.removeAll()
    }

    /// 重新创建插件实例
    /// - Parameter plugin: 插件对象
    /// - Returns: 新的插件实例
    func recreateInstance(for plugin: Plugin) -> PluginInstance? {
        destroyInstance(for: plugin.name)
        return createInstance(for: plugin)
    }

    /// 获取所有活动的插件实例
    /// - Returns: 插件实例数组
    func getAllInstances() -> [PluginInstance] {
        return Array(instances.values)
    }

    /// 检查插件实例是否存在
    /// - Parameter pluginName: 插件名称
    /// - Returns: 是否存在
    func hasInstance(for pluginName: String) -> Bool {
        return instances[pluginName] != nil
    }

    // MARK: - 私有方法

    private func setupInstance(_ instance: PluginInstance) throws {
        // 创建 JavaScript 上下文
        let context = JSContext()
        guard let context = context else {
            throw PluginError.executionFailed("无法创建 JavaScript 上下文")
        }

        // 设置异常处理
        context.exceptionHandler = { context, exception in
            print("插件 JavaScript 异常 (\(instance.plugin.name)): \(exception?.toString() ?? "未知异常")")
        }

        // 创建并注入 API 管理器
        let apiManager = APIManager(pluginInstance: instance)
        apiManager.injectAPIs(into: context)

        // 设置实例属性
        instance.context = context
        instance.apiManager = apiManager

        // 执行插件脚本
        let script = instance.plugin.script
        let result = context.evaluateScript(script)

        if let exception = context.exception {
            throw PluginError.scriptEvaluationFailed(
                "脚本执行失败: \(String(describing: exception.toString()))")
        }

        if result?.isUndefined == true {
            throw PluginError.scriptEvaluationFailed("脚本执行没有返回值")
        }

        print("插件脚本执行成功: \(instance.plugin.name)")
    }

    /// 获取实例统计信息
    /// - Returns: 统计信息字典
    func getInstanceStatistics() -> [String: Any] {
        return [
            "total": instances.count,
            "active": instances.values.filter { $0.isEnabled }.count,
            "inactive": instances.values.filter { !$0.isEnabled }.count,
            "instances": instances.keys.sorted(),
        ]
    }

    /// 重启所有插件实例
    func restartAllInstances() async {
        let pluginManager = PluginManager.shared
        let plugins = pluginManager.getLoadedPlugins()

        // 销毁现有实例
        destroyAllInstances()

        // 重新创建实例
        for plugin in plugins {
            if plugin.isEnabled {
                _ = createInstance(for: plugin)
            }
        }
    }

    /// 启用插件实例
    /// - Parameter pluginName: 插件名称
    func enableInstance(for pluginName: String) {
        if let instance = instances[pluginName] {
            instance.isEnabled = true
            print("插件实例已启用: \(pluginName)")
        }
    }

    /// 禁用插件实例
    /// - Parameter pluginName: 插件名称
    func disableInstance(for pluginName: String) {
        if let instance = instances[pluginName] {
            instance.isEnabled = false
            print("插件实例已禁用: \(pluginName)")
        }
    }
}
