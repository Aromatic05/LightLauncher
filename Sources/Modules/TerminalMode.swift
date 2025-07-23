import Foundation
import AppKit
import SwiftUI
import Combine

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
import SwiftUI

@MainActor
final class TerminalModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = TerminalModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation

    // 1. 身份与元数据
    let mode: LauncherMode = .terminal
    let prefix: String? = ">"
    let displayName: String = "Terminal"
    let iconName: String = "terminal"
    let placeholder: String = "Enter terminal command to execute..."
    let modeDescription: String? = "Execute shell commands"

    @Published var currentQuery: String = ""

    var displayableItems: [any DisplayableItem] {
        // This mode only shows one item: the command to be executed.
        return currentQuery.isEmpty ? [] : [CurrentCommandItem(title: currentQuery)]
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        self.currentQuery = arguments
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        // This mode executes the current query, regardless of the index.
        return executeTerminalCommandWithDetection(command: currentQuery)
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.currentQuery = ""
    }

    func makeContentView() -> AnyView {
        return AnyView(TerminalCommandInputView(searchText: self.currentQuery))
    }



    func getHelpText() -> [String] {
        return [
            "Type after /t to enter a shell command",
            "Press Enter to run the command in your terminal",
            "Press Esc to exit"
        ]
    }

    // MARK: - Private Terminal Execution Logic
    
    private func executeTerminalCommandWithDetection(command: String) -> Bool {
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCommand.isEmpty else { return false }
        
        let preferredTerminal = ConfigManager.shared.config.modes.preferredTerminal
        
        switch preferredTerminal {
        case "auto":      return executeWithAutoDetection(command: cleanCommand)
        case "terminal":  return executeWithTerminal(command: cleanCommand)
        case "iterm2":    return executeWithITerm2(command: cleanCommand) || executeWithAutoDetection(command: cleanCommand)
        case "ghostty":   return executeWithGhostty(command: cleanCommand) || executeWithAutoDetection(command: cleanCommand)
        case "kitty":     return executeWithKitty(command: cleanCommand) || executeWithAutoDetection(command: cleanCommand)
        case "alacritty": return executeWithAlacritty(command: cleanCommand) || executeWithAutoDetection(command: cleanCommand)
        case "wezterm":   return executeWithWezTerm(command: cleanCommand) || executeWithAutoDetection(command: cleanCommand)
        default:          return executeWithAutoDetection(command: cleanCommand)
        }
    }

    private func executeWithAutoDetection(command: String) -> Bool {
        let terminalPriority: [(String, (String) -> Bool)] = [
            ("iTerm2", executeWithITerm2), ("Ghostty", executeWithGhostty),
            ("Kitty", executeWithKitty), ("WezTerm", executeWithWezTerm),
            ("Alacritty", executeWithAlacritty), ("Terminal", executeWithTerminal)
        ]
        for (_, executor) in terminalPriority {
            if executor(command) { return true }
        }
        return false // Fallback to do nothing if no terminal is found
    }

    private func isApplicationInstalled(_ bundleIdentifier: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    private func executeWithTerminal(command: String) -> Bool {
        guard isApplicationInstalled("com.apple.Terminal") else { return false }
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        guard let script = NSAppleScript(source: appleScript) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    private func executeWithITerm2(command: String) -> Bool {
        guard isApplicationInstalled("com.googlecode.iterm2") else { return false }
        let appleScript = """
        tell application "iTerm"
            activate
            tell current window
                create tab with default profile
                tell current session
                    write text "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
                end tell
            end tell
        end tell
        """
        guard let script = NSAppleScript(source: appleScript) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
    
    // Command-line execution for modern terminals
    private func executeWithModernTerminal(appName: String, bundleId: String, args: [String]) -> Bool {
        guard isApplicationInstalled(bundleId) else { return false }
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-n", "-a", appName, "--args"] + args
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
    
    private func executeWithGhostty(command: String) -> Bool {
        let shellCommand = "zsh -c '\(command.replacingOccurrences(of: "'", with: "'\\''")); zsh -l'"
        return executeWithModernTerminal(appName: "Ghostty", bundleId: "com.mitchellh.ghostty", args: ["-e", shellCommand])
    }

    private func executeWithKitty(command: String) -> Bool {
        return executeWithModernTerminal(appName: "kitty", bundleId: "net.kovidgoyal.kitty", args: ["--hold", "-e", "zsh", "-c", command])
    }

    private func executeWithAlacritty(command: String) -> Bool {
        return executeWithModernTerminal(appName: "Alacritty", bundleId: "io.alacritty", args: ["--hold", "-e", "zsh", "-c", command])
    }

    private func executeWithWezTerm(command: String) -> Bool {
        return executeWithModernTerminal(appName: "WezTerm", bundleId: "com.github.wez.wezterm", args: ["start", "--", "zsh", "-c", command])
    }
}