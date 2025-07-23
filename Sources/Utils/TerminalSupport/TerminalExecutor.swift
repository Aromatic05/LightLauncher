import Foundation
import AppKit

/// 定义了一个终端执行器的通用接口。
/// 每个实现者代表一种与特定终端应用交互的“策略”。
protocol TerminalExecutor {
    /// 终端应用的名称 (用于日志或UI)。
    var name: String { get }
    
    /// 终端应用的 Bundle Identifier (用于检测是否安装)。
    var bundleIdentifier: String { get }
    
    /// 检查此终端是否已安装。
    func isInstalled() -> Bool
    
    /// 在此终端中执行命令。
    /// - Returns: `true` 表示成功尝试执行，`false` 表示失败或终端未安装。
    func execute(command: String) -> Bool
}

extension TerminalExecutor {
    // 提供一个默认的 isInstalled 实现
    func isInstalled() -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}
