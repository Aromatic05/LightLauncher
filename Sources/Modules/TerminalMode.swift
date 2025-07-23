import Foundation
import AppKit
import SwiftUI

struct CurrentCommandItem: DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(TerminalCommandInputView(searchText: title))
    }
    let id = UUID()
    let title: String
    var subtitle: String? { "将要执行的命令: \(title)" }
    var icon: NSImage? { nil }
}

// MARK: - 终端模式控制器
@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = TerminalModeController()
    private override init() {}
    var prefix: String? { "/t" }
    @Published var currentQuery: String = ""
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        var items: [any DisplayableItem] = []
        if !currentQuery.isEmpty {
            items.append(CurrentCommandItem(title: currentQuery))
        }
        return items
    }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/t")
    }
    // 2. 进入模式
    func enterMode(with text: String) {
        currentQuery = extractQuery(from: text)
        LauncherViewModel.shared.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String) {
        currentQuery = extractQuery(from: text)
        LauncherViewModel.shared.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int) -> Bool {
        let cleanText = self.extractCleanTerminalText(from: LauncherViewModel.shared.searchText)
        return executeTerminalCommandWithDetection(command: cleanText)
    }
    // 5. 退出条件
    func shouldExit(for text: String) -> Bool {
        return !text.hasPrefix("/t")
    }
    // 6. 清理操作
    func cleanup() {}

    // 元信息属性
    var displayName: String { "Terminal" }
    var iconName: String { "terminal" }
    var placeholder: String { "Enter terminal command..." }
    var modeDescription: String? { "Execute commands in Terminal" }

    private func extractQuery(from text: String) -> String {
        let prefix = "/t "
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // --- 终端检测与执行相关辅助方法 ---
    private func executeTerminalCommandWithDetection(command: String) -> Bool {
        let configManager = ConfigManager.shared
        let preferredTerminal = configManager.config.modes.preferredTerminal
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        switch preferredTerminal {
        case "auto":
            return executeWithAutoDetection(command: cleanCommand)
        case "terminal":
            return executeWithTerminal(command: cleanCommand)
        case "iterm2":
            return executeWithITerm2(command: cleanCommand) || executeWithFallback(command: cleanCommand)
        case "ghostty":
            return executeWithGhostty(command: cleanCommand) || executeWithFallback(command: cleanCommand)
        case "kitty":
            return executeWithKitty(command: cleanCommand) || executeWithFallback(command: cleanCommand)
        case "alacritty":
            return executeWithAlacritty(command: cleanCommand) || executeWithFallback(command: cleanCommand)
        case "wezterm":
            return executeWithWezTerm(command: cleanCommand) || executeWithFallback(command: cleanCommand)
        default:
            return executeWithAutoDetection(command: cleanCommand)
        }
    }
    private func executeWithAutoDetection(command: String) -> Bool {
        if let defaultTerminal = getSystemDefaultTerminal() {
            switch defaultTerminal {
            case "com.apple.Terminal":
                if executeWithTerminal(command: command) { return true }
            case "com.googlecode.iterm2":
                if executeWithITerm2(command: command) { return true }
            case "com.mitchellh.ghostty":
                if executeWithGhostty(command: command) { return true }
            case "net.kovidgoyal.kitty":
                if executeWithKitty(command: command) { return true }
            case "io.alacritty":
                if executeWithAlacritty(command: command) { return true }
            case "com.github.wez.wezterm":
                if executeWithWezTerm(command: command) { return true }
            default: break
            }
        }
        let terminalPriority: [(String, (String) -> Bool)] = [
            ("iTerm2", executeWithITerm2),
            ("Ghostty", executeWithGhostty),
            ("Kitty", executeWithKitty),
            ("WezTerm", executeWithWezTerm),
            ("Alacritty", executeWithAlacritty),
            ("Terminal", executeWithTerminal)
        ]
        for (_, executor) in terminalPriority {
            if executor(command) { return true }
        }
        return executeDirectly(command: command)
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
    private func executeWithFallback(command: String) -> Bool {
        return executeWithAutoDetection(command: command)
    }
    private func executeWithTerminal(command: String) -> Bool {
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
        return true
    }
    private func executeWithITerm2(command: String) -> Bool {
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
        guard let script = NSAppleScript(source: appleScript) else { return executeDirectly(command: command) }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if error != nil { return executeDirectly(command: command) }
        return true
    }
    private func executeWithGhostty(command: String) -> Bool {
        guard isApplicationInstalled("com.mitchellh.ghostty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        // 构造命令：open -n -a "Ghostty" --args -e "zsh -c '<command>; zsh -l'"
        let shellCommand = "zsh -c '" + command.replacingOccurrences(of: "'", with: "'\\''") + "; zsh -l'"
        process.arguments = ["-n", "-a", "Ghostty", "--args", "-e", shellCommand]
        do {
            try process.run()
            return true
        } catch { return false }
    }
    private func executeWithKitty(command: String) -> Bool {
        guard isApplicationInstalled("net.kovidgoyal.kitty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-n", "-a", "kitty", "--args", "--hold", "-e", "zsh", "-c", command]
        do {
            try process.run()
            return true
        } catch { return false }
    }
    private func executeWithAlacritty(command: String) -> Bool {
        guard isApplicationInstalled("io.alacritty") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-n", "-a", "Alacritty", "--args", "--hold", "-e", "zsh", "-c", command]
        do {
            try process.run()
            return true
        } catch { return false }
    }
    private func executeWithWezTerm(command: String) -> Bool {
        guard isApplicationInstalled("com.github.wez.wezterm") else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-n", "-a", "WezTerm", "--args", "start", "--", "zsh", "-c", command]
        do {
            try process.run()
            return true
        } catch { return false }
    }
    private func isApplicationInstalled(_ bundleIdentifier: String) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
    private func executeDirectly(command: String) -> Bool {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        do {
            try process.run()
            return true
        } catch {
            print("Failed to execute command: \(error)")
            return false
        }
    }

    // 生成内容视图
    func makeContentView() -> AnyView {
        return AnyView(TerminalCommandInputView(searchText: LauncherViewModel.shared.searchText))
    }

    func getHelpText() -> [String] {
        return [
            "Type after /t to execute terminal command",
            "Press Enter to run in Terminal",
            "Delete /t prefix to return to launch mode",
            "Press Esc to close"
        ]
    }

    // --- 从 LauncherViewModel extension 移动过来的方法 ---
    func extractCleanTerminalText(from searchText: String) -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}