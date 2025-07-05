import Foundation
import AppKit

// MARK: - 终端模式控制器
@MainActor
class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    var prefix: String? { "/t" }
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] { [] }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/t")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        let cleanText = viewModel.extractCleanTerminalText()
        return executeTerminalCommandWithDetection(command: cleanText, viewModel: viewModel)
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        return !text.hasPrefix("/t")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {}

    // --- 终端检测与执行相关辅助方法 ---
    private func executeTerminalCommandWithDetection(command: String, viewModel: LauncherViewModel) -> Bool {
        let configManager = ConfigManager.shared
        let preferredTerminal = configManager.config.modes.preferredTerminal
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        switch preferredTerminal {
        case "auto":
            return executeWithAutoDetection(command: cleanCommand, viewModel: viewModel)
        case "terminal":
            return executeWithTerminal(command: cleanCommand, viewModel: viewModel)
        case "iterm2":
            return executeWithITerm2(command: cleanCommand, viewModel: viewModel) || executeWithFallback(command: cleanCommand, viewModel: viewModel)
        case "ghostty":
            return executeWithGhostty(command: cleanCommand, viewModel: viewModel) || executeWithFallback(command: cleanCommand, viewModel: viewModel)
        case "kitty":
            return executeWithKitty(command: cleanCommand, viewModel: viewModel) || executeWithFallback(command: cleanCommand, viewModel: viewModel)
        case "alacritty":
            return executeWithAlacritty(command: cleanCommand, viewModel: viewModel) || executeWithFallback(command: cleanCommand, viewModel: viewModel)
        case "wezterm":
            return executeWithWezTerm(command: cleanCommand, viewModel: viewModel) || executeWithFallback(command: cleanCommand, viewModel: viewModel)
        default:
            return executeWithAutoDetection(command: cleanCommand, viewModel: viewModel)
        }
    }
    private func executeWithAutoDetection(command: String, viewModel: LauncherViewModel) -> Bool {
        if let defaultTerminal = getSystemDefaultTerminal() {
            switch defaultTerminal {
            case "com.apple.Terminal":
                if executeWithTerminal(command: command, viewModel: viewModel) { return true }
            case "com.googlecode.iterm2":
                if executeWithITerm2(command: command, viewModel: viewModel) { return true }
            case "com.mitchellh.ghostty":
                if executeWithGhostty(command: command, viewModel: viewModel) { return true }
            case "net.kovidgoyal.kitty":
                if executeWithKitty(command: command, viewModel: viewModel) { return true }
            case "io.alacritty":
                if executeWithAlacritty(command: command, viewModel: viewModel) { return true }
            case "com.github.wez.wezterm":
                if executeWithWezTerm(command: command, viewModel: viewModel) { return true }
            default: break
            }
        }
        let terminalPriority: [(String, (String, LauncherViewModel) -> Bool)] = [
            ("iTerm2", executeWithITerm2),
            ("Ghostty", executeWithGhostty),
            ("Kitty", executeWithKitty),
            ("WezTerm", executeWithWezTerm),
            ("Alacritty", executeWithAlacritty),
            ("Terminal", executeWithTerminal)
        ]
        for (_, executor) in terminalPriority {
            if executor(command, viewModel) { return true }
        }
        return executeDirectly(command: command, viewModel: viewModel)
    }
    private func getSystemDefaultTerminal() -> String? {
        let workspace = NSWorkspace.shared
        let tempShellScript = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.sh")
        do {
            try "#!/bin/bash\necho test".write(to: tempShellScript, atomically: true, encoding: .utf8)
            let defaultApp = workspace.urlForApplication(toOpen: tempShellScript)
            try FileManager.default.removeItem(at: tempShellScript)
            if let appURL = defaultApp {
                let bundle = Bundle(url: appURL)
                return bundle?.bundleIdentifier
            }
        } catch {
            print("检测默认终端失败: \(error)")
        }
        return nil
    }
    private func executeWithFallback(command: String, viewModel: LauncherViewModel) -> Bool {
        return executeWithAutoDetection(command: command, viewModel: viewModel)
    }
    private func executeWithTerminal(command: String, viewModel: LauncherViewModel) -> Bool {
        let appleScript = """
        tell application \"Terminal\"
            activate
            do script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\"
        end tell
        """
        guard let script = NSAppleScript(source: appleScript) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if error != nil { return false }
        viewModel.resetToLaunchMode()
        return true
    }
    private func executeWithITerm2(command: String, viewModel: LauncherViewModel) -> Bool {
        let appleScript = """
        tell application \"iTerm\"
            activate
            tell current window
                create tab with default profile
                tell current session
                    write text \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\"
                end tell
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: appleScript) else { return executeDirectly(command: command, viewModel: viewModel) }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if error != nil { return executeDirectly(command: command, viewModel: viewModel) }
        viewModel.resetToLaunchMode()
        return true
    }
    private func executeWithGhostty(command: String, viewModel: LauncherViewModel) -> Bool {
        guard isApplicationInstalled("com.mitchellh.ghostty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "Ghostty", "--args", "-e", "zsh", "-c", command]
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch { return false }
    }
    private func executeWithKitty(command: String, viewModel: LauncherViewModel) -> Bool {
        guard isApplicationInstalled("net.kovidgoyal.kitty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "kitty", "--args", "--hold", "-e", "zsh", "-c", command]
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch { return false }
    }
    private func executeWithAlacritty(command: String, viewModel: LauncherViewModel) -> Bool {
        guard isApplicationInstalled("io.alacritty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "Alacritty", "--args", "--hold", "-e", "zsh", "-c", command]
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch { return false }
    }
    private func executeWithWezTerm(command: String, viewModel: LauncherViewModel) -> Bool {
        guard isApplicationInstalled("com.github.wez.wezterm") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "WezTerm", "--args", "start", "--", "zsh", "-c", command]
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch { return false }
    }
    private func isApplicationInstalled(_ bundleIdentifier: String) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
    private func executeDirectly(command: String, viewModel: LauncherViewModel) -> Bool {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch {
            print("Failed to execute command: \(error)")
            return false
        }
    }
}

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    func switchToTerminalMode() {
        mode = .terminal
        selectedIndex = 0
    }
    
    func extractCleanTerminalText() -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 终端命令建议提供器
struct TerminalCommandSuggestionProvider: CommandSuggestionProvider {
    static func getHelpText() -> [String] {
        return [
            "Type after /t to execute terminal command",
            "Press Enter to run in Terminal",
            "Delete /t prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}

