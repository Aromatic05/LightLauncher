import AppKit
import Darwin
import Foundation

struct ShellCommandBuilder {
    static func defaultShellPath(environment: [String: String] = ProcessInfo.processInfo.environment)
        -> String
    {
        if let shell = environment["SHELL"], !shell.isEmpty {
            return shell
        }

        if let passwordEntry = getpwuid(getuid()),
            let shellPointer = passwordEntry.pointee.pw_shell
        {
            let shell = String(cString: shellPointer)
            if !shell.isEmpty {
                return shell
            }
        }

        return "/bin/zsh"
    }

    static func interactiveShellArguments(
        for command: String,
        shellPath: String = defaultShellPath()
    ) -> [String] {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let shellCommand = "\(trimmedCommand); exec \(shellPath.shellEscaped) -l"
        return [shellPath, "-lc", shellCommand]
    }
}

private extension String {
    var shellEscaped: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// 策略 1: Apple Terminal (使用 AppleScript)
struct AppleTerminalExecutor: TerminalExecutor, @unchecked Sendable {
    let name = "Terminal"
    let bundleIdentifier = "com.apple.Terminal"

    func execute(command: String) -> Bool {
        guard isInstalled() else { return false }
        let scriptSource = """
            tell application \"Terminal\"
                activate
                do script \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\"
            end tell
            """
        guard let script = NSAppleScript(source: scriptSource) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    static let shared = AppleTerminalExecutor()
}

// 策略 2: iTerm2 (使用 AppleScript)
struct ITerm2Executor: TerminalExecutor, @unchecked Sendable {
    let name = "iTerm2"
    let bundleIdentifier = "com.googlecode.iterm2"

    func execute(command: String) -> Bool {
        guard isInstalled() else { return false }
        let scriptSource = """
            tell application \"iTerm\"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current window
                    create tab with default profile
                    tell current session of current tab
                        write text \"\(command.replacingOccurrences(of: "\"", with: "\\\""))\"
                    end tell
                end tell
            end tell
            """
        guard let script = NSAppleScript(source: scriptSource) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    static let shared = ITerm2Executor()
}

// 策略 3: 现代终端的基类 (使用命令行)
/// 这是一个辅助的基类，用于处理通过命令行 `open` 命令启动的现代终端
struct ModernTerminalExecutor: TerminalExecutor, @unchecked Sendable {
    let name: String
    let bundleIdentifier: String
    let arguments: (String) -> [String]  // 一个闭包，用于根据命令生成参数

    func execute(command: String) -> Bool {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier)
        else { return false }

        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-n", "-a", applicationURL.path, "--args"] + arguments(command)
        do {
            try process.run()
            return true
        } catch {
            Logger.shared.error(
                "Failed to launch terminal '\(name)': \(error.localizedDescription)", owner: self)
            return false
        }
    }
}

// 具体的现代终端策略，现在只需提供配置即可
extension ModernTerminalExecutor {
    static let GhosttyExecutor = ModernTerminalExecutor(
        name: "Ghostty", bundleIdentifier: "com.mitchellh.ghostty"
    ) { command in
        return ["-e"] + ShellCommandBuilder.interactiveShellArguments(for: command)
    }
    static let sharedGhostty = GhosttyExecutor

    static let KittyExecutor = ModernTerminalExecutor(
        name: "kitty", bundleIdentifier: "net.kovidgoyal.kitty"
    ) { command in
        return ["--hold"] + ShellCommandBuilder.interactiveShellArguments(for: command)
    }
    static let sharedKitty = KittyExecutor

    static let AlacrittyExecutor = ModernTerminalExecutor(
        name: "Alacritty", bundleIdentifier: "io.alacritty"
    ) { command in
        return ["--hold", "-e"] + ShellCommandBuilder.interactiveShellArguments(for: command)
    }
    static let sharedAlacritty = AlacrittyExecutor

    static let WezTermExecutor = ModernTerminalExecutor(
        name: "WezTerm", bundleIdentifier: "com.github.wez.wezterm"
    ) { command in
        return ["start", "--"] + ShellCommandBuilder.interactiveShellArguments(for: command)
    }
    static let sharedWezTerm = WezTermExecutor
}
