// file: LauncherMode.swift
import Foundation
import AppKit

// MARK: - 启动器模式枚举（已简化）
enum LauncherMode: String, CaseIterable {
    case launch, kill, search, web, terminal, file, clip, plugin
    
    // --- 元信息获取逻辑保持不变 ---
    // 这些计算属性仍然依赖于从 ViewModel 的控制器字典中查找实例，这是合理的。
    @MainActor
    var displayName: String {
        LauncherViewModel.shared.controllers[self]?.displayName ?? self.rawValue
    }
    @MainActor
    var iconName: String {
        LauncherViewModel.shared.controllers[self]?.iconName ?? "questionmark"
    }
    @MainActor
    var placeholder: String {
        LauncherViewModel.shared.controllers[self]?.placeholder ?? ""
    }
    @MainActor
    var description: String? {
        LauncherViewModel.shared.controllers[self]?.modeDescription
    }
    
    // --- 已移除的逻辑 ---
    // 移除了硬编码的 'trigger' 计算属性。前缀现在由每个控制器自己定义。
    // 移除了 'fromPrefix' 静态方法。此逻辑现在由 CommandRegistry 高效处理。
    
    // --- 保留的逻辑 ---
    
    /// 检查模式是否在设置中启用，此功能依然需要。
    @MainActor
    func isEnabled() -> Bool {
        // 假设 SettingsManager 存在
        let settings = SettingsManager.shared
        return settings.isModeEnabled(self.rawValue)
    }
}

// file: LauncherCommand.swift
import Foundation

// MARK: - 命令建议提供者（已重构）
// 这个结构体的职责现在是作为UI层和CommandRegistry之间获取建议的桥梁。
struct LauncherCommand {
    
    /**
     * 根据用户输入，从注册中心获取命令建议。
     *
     * @param text 用户当前的输入文本。
     * @return 返回一个 CommandRecord 数组，可直接用于UI渲染。
     */
    @MainActor
    static func getSuggestions(for text: String) -> [CommandRecord] {
        // 如果输入不是以 "/" 开头，则不提供任何命令建议。
        guard text.hasPrefix("/") else {
            return []
        }
        
        // 从注册中心一次性获取所有缓存好的命令记录。
        let allCommands = CommandRegistry.shared.getCommandSuggestions()
        
        // 如果用户只输入了 "/"，显示所有可用的命令。
        if text == "/" {
            return allCommands
        }
        
        // 否则，在缓存的记录中进行高效过滤。
        return allCommands.filter { $0.prefix.hasPrefix(text) }
    }
    
    // --- 已移除的逻辑 ---
    // 移除了所有旧的属性 (trigger, mode, description, etc.)。
    // 移除了所有旧的静态方法 (allCommands, parseCommand, getEnabledCommands)，
    // 因为它们的功能已被 CommandRegistry 和 getSuggestions(for:) 完全取代。
    // 插件命令现在也应该通过注册一个控制器来统一处理。
}