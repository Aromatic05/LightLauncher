// CommandRegistry.swift

import Foundation

/**
 * @struct CommandRecord
 * @brief 存储一个已注册命令的所有相关信息。
 *
 * 这是 CommandRegistry 中缓存的核心数据单元，既包含了用于快速UI呈现的元数据，
 * 也包含了执行命令逻辑所需的控制器实例。
 * 它的生命周期与应用同样长，在注册后不会改变。
 */
@MainActor
struct CommandRecord {
    /// 触发命令的唯一前缀，例如 "/s" 或 "/k"。
    let prefix: String
    
    /// 命令所关联的启动器模式。
    let mode: LauncherMode
    
    // --- 用于快速呈现的UI元数据缓存 ---
    
    /// 命令的显示名称，例如 "Search Web"
    let displayName: String
    
    /// 用于在UI中显示的图标名称 (例如 SFSymbols 的名称)。
    let iconName: String
    
    /// 对命令功能的简短描述，用于建议列表中的提示。
    let description: String?
    
    /// 负责处理该命令逻辑的具体控制器实例。
    let controller: ModeStateController
}


/**
 * @class CommandRegistry
 * @brief 管理应用中所有前缀命令的注册、查找和建议。
 *
 * 这是一个线程安全的单例类（通过 @MainActor），作为所有命令的“单一事实来源”(Single Source of Truth)。
 * 它通过一个字典高效地将命令前缀映射到包含元数据和逻辑处理器的 CommandRecord。
 *
 * - 注册: 控制器在初始化时调用 `register()` 来加入命令系统。
 * - 查找: `processInput()` 调用 `findCommand()` 来分发用户输入的命令。
 * - 建议: UI层调用 `getCommandSuggestions()` 来获取动态补全列表。
 */
@MainActor
final class CommandRegistry {
    
    /// 全局共享的唯一实例。
    static let shared = CommandRegistry()
    
    /// 核心数据结构：[Prefix: CommandRecord]。
    /// 使用字典（哈希表）确保了根据前缀查找命令的时间复杂度为 O(1)。
    private var prefixMap: [String: CommandRecord] = [:]
    
    /// 私有化构造器，确保了这是一个真正的单例。
    private init() {}
    
    // MARK: - Public API
    
    /**
     * 注册一个控制器及其对应的命令前缀和元数据。
     * 这个方法应该在控制器初始化时被调用。
     *
     * @param controller 实现了 ModeStateController 协议的控制器实例。
     */
    func register(_ controller: ModeStateController) {
        // 安全校验：确保模式已启用，并且拥有一个非空的前缀
        guard controller.mode.isEnabled(),
              let prefix = controller.prefix,
              !prefix.isEmpty else {
            return
        }
        
        // 防止重复注册
        guard prefixMap[prefix] == nil else {
            print("⚠️ Warning: Command prefix '\(prefix)' is already registered. Ignoring new registration.")
            return
        }
        
        // 创建一个包含所有信息的 CommandRecord
        let record = CommandRecord(
            prefix: prefix,
            mode: controller.mode,
            displayName: controller.displayName,
            iconName: controller.iconName,
            description: controller.modeDescription,
            controller: controller
        )
        
        // 注册到前缀池中
        prefixMap[prefix] = record
        print("✅ Command registered: '\(record.prefix)' -> \(record.displayName)")
    }
    
    /**
     * 根据用户的完整输入文本，高效地查找匹配的命令和提取参数。
     *
     * @param text 用户的完整输入，例如 "/s my search query"。
     * @return 一个可选的元组，如果找到匹配的命令，则包含完整的`CommandRecord`和去除前缀后的参数字符串。
     */
    func findCommand(for text: String) -> (record: CommandRecord, arguments: String)? {
        // 使用 `split` 并限制次数为1，这是分离命令和参数最高效的方式
        let components = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        
        // 获取第一个部分作为可能的前缀
        guard let potentialPrefix = components.first.map(String.init) else {
            return nil
        }
        
        // 在字典中进行 O(1) 查找
        if let record = prefixMap[potentialPrefix] {
            // 如果找到了记录，则剩余部分是参数
            let arguments = components.count > 1 ? String(components[1]) : ""
            return (record, arguments)
        }
        
        return nil
    }
    
    /**
     * 获取所有已注册的、可用于UI建议列表的命令。
     * 这个方法性能极高，因为它直接返回缓存的数据。
     *
     * @return 一个包含所有命令记录的数组，已按前缀字母顺序排序。
     */
    func getCommandSuggestions() -> [CommandRecord] {
        //直接返回字典中的所有值，并进行排序以保证UI呈现的顺序一致性。
        return Array(prefixMap.values).sorted { $0.prefix < $1.prefix }
    }
}