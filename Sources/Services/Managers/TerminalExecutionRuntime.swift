import Foundation

@MainActor
final class TerminalExecutionRuntime {
    static let shared = TerminalExecutionRuntime()

    private let executors: [TerminalExecutor]

    private init() {
        executors = [
            ITerm2Executor.shared,
            ModernTerminalExecutor.sharedGhostty,
            ModernTerminalExecutor.sharedKitty,
            ModernTerminalExecutor.sharedWezTerm,
            ModernTerminalExecutor.sharedAlacritty,
            AppleTerminalExecutor.shared,
        ]
    }

    func execute(command: String) -> Bool {
        guard PermissionManager.shared.checkTerminalPermissions() else {
            Logger.shared.warning(
                "Terminal execution blocked: automation permission missing",
                owner: self
            )
            PermissionPromptService.shared.prompt(for: .automation)
            return false
        }

        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCommand.isEmpty else { return false }

        let preferredTerminalName = ConfigManager.shared.config.modes.preferredTerminal
        Logger.shared.debug(
            "Executing terminal command with preferred terminal '\(preferredTerminalName)'",
            owner: self
        )

        if preferredTerminalName != "auto",
            let preferredExecutor = executors.first(where: {
                $0.name.lowercased() == preferredTerminalName.lowercased()
            })
        {
            if preferredExecutor.execute(command: cleanCommand) {
                Logger.shared.info(
                    "Executed terminal command via preferred terminal '\(preferredExecutor.name)'",
                    owner: self
                )
                return true
            }

            Logger.shared.warning(
                "Preferred terminal '\(preferredExecutor.name)' failed, falling back to auto detection",
                owner: self
            )
        }

        return executeWithAutoDetection(command: cleanCommand)
    }

    private func executeWithAutoDetection(command: String) -> Bool {
        for executor in executors {
            if executor.execute(command: command) {
                Logger.shared.info(
                    "Executed terminal command via auto-detected terminal '\(executor.name)'",
                    owner: self
                )
                return true
            }
        }

        Logger.shared.error(
            "Failed to execute terminal command in any supported terminal",
            owner: self
        )
        return false
    }
}
