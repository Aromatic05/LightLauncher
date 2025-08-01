import Foundation

@MainActor
final class TerminalExecutorService {
    static let shared = TerminalExecutorService()

    /// 定义了所有支持的终端策略及其优先级（用于自动检测）
    private let executors: [TerminalExecutor]

    private init() {
        // 在这里定义所有支持的终端和它们的优先级顺序
        self.executors = [
            ITerm2Executor.shared,
            ModernTerminalExecutor.sharedGhostty,
            ModernTerminalExecutor.sharedKitty,
            ModernTerminalExecutor.sharedWezTerm,
            ModernTerminalExecutor.sharedAlacritty,
            AppleTerminalExecutor.shared
        ]
    }

    /// 公共的执行入口点
    func execute(command: String) -> Bool {
        // 检查终端执行权限
        guard PermissionManager.shared.checkTerminalPermissions() else {
            Task { @MainActor in
                PermissionManager.shared.withPermission(.automation) {
                    // 权限获得后重新执行
                    _ = self.execute(command: command)
                }
            }
            return false
        }

        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCommand.isEmpty else { return false }
        
        let preferredTerminalName = ConfigManager.shared.config.modes.preferredTerminal
        
        // 如果用户有偏好设置
        if preferredTerminalName != "auto",
           let preferredExecutor = executors.first(where: { $0.name.lowercased() == preferredTerminalName.lowercased() }) {
            // 尝试使用偏好的终端，如果失败，则回退到自动检测
            if preferredExecutor.execute(command: cleanCommand) {
                return true
            }
        }
        
        // 自动检测
        return executeWithAutoDetection(command: cleanCommand)
    }

    private func executeWithAutoDetection(command: String) -> Bool {
        // 按优先级顺序遍历所有执行器，找到第一个已安装的并执行
        for executor in executors {
            if executor.execute(command: command) {
                return true
            }
        }
        return false // 如果所有终端都失败
    }
}
