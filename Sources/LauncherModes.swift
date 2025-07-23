import AppKit
// file: LauncherMode.swift
import Foundation

// MARK: - 启动器模式枚举（已简化）
enum LauncherMode: String, CaseIterable {
    case launch, kill, search, web, terminal, file, clip, plugin
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

    /// 检查模式是否在设置中启用，此功能依然需要。
    @MainActor
    func isEnabled() -> Bool {
        // 假设 SettingsManager 存在
        let settings = SettingsManager.shared
        return settings.isModeEnabled(self.rawValue)
    }
}

// MARK: - 命令建议提供者
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
        guard let firstChar = text.first else {
            return []
        }
        guard !firstChar.isLetter else {
            return []
        }
        let allCommands = CommandRegistry.shared.getCommandSuggestions()
        return allCommands.filter { $0.prefix.hasPrefix(text) }
    }
}
