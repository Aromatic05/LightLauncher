import Foundation
import AppKit

// MARK: - 终端命令处理器
@MainActor
class TerminalCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/t"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/t" else { return false }
        viewModel.switchToTerminalMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 在终端模式下，直接显示命令文本，不需要过滤
        // 用户按回车时会执行命令
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .terminal else { return false }
        
        // 提取命令文本，去掉 "/t " 前缀
        let commandText = viewModel.searchText.hasPrefix("/t ") ? 
            String(viewModel.searchText.dropFirst(3)) : viewModel.searchText
        
        guard !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return executeTerminalCommand(command: commandText, in: viewModel)
    }
    
    private func executeTerminalCommand(command: String, in viewModel: LauncherViewModel) -> Bool {
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let configManager = ConfigManager.shared
        let preferredTerminal = configManager.config.modes.preferredTerminal
        
        switch preferredTerminal {
        case "auto":
            return executeWithAutoDetection(command: cleanCommand, in: viewModel)
        case "terminal":
            return executeWithTerminal(command: cleanCommand, in: viewModel)
        case "iterm2":
            return executeWithITerm2(command: cleanCommand, in: viewModel) ||
                   executeWithFallback(command: cleanCommand, in: viewModel)
        case "ghostty":
            return executeWithGhostty(command: cleanCommand, in: viewModel) ||
                   executeWithFallback(command: cleanCommand, in: viewModel)
        case "kitty":
            return executeWithKitty(command: cleanCommand, in: viewModel) ||
                   executeWithFallback(command: cleanCommand, in: viewModel)
        case "alacritty":
            return executeWithAlacritty(command: cleanCommand, in: viewModel) ||
                   executeWithFallback(command: cleanCommand, in: viewModel)
        case "wezterm":
            return executeWithWezTerm(command: cleanCommand, in: viewModel) ||
                   executeWithFallback(command: cleanCommand, in: viewModel)
        default:
            return executeWithAutoDetection(command: cleanCommand, in: viewModel)
        }
    }
    
    private func executeWithAutoDetection(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 首先尝试检测系统默认终端
        if let defaultTerminal = getSystemDefaultTerminal() {
            print("检测到系统默认终端: \(defaultTerminal)")
            switch defaultTerminal {
            case "com.apple.Terminal":
                if executeWithTerminal(command: command, in: viewModel) { return true }
            case "com.googlecode.iterm2":
                if executeWithITerm2(command: command, in: viewModel) { return true }
            case "com.mitchellh.ghostty":
                if executeWithGhostty(command: command, in: viewModel) { return true }
            case "net.kovidgoyal.kitty":
                if executeWithKitty(command: command, in: viewModel) { return true }
            case "io.alacritty":
                if executeWithAlacritty(command: command, in: viewModel) { return true }
            case "com.github.wez.wezterm":
                if executeWithWezTerm(command: command, in: viewModel) { return true }
            default:
                break
            }
        }
        
        // 如果默认检测失败，按优先级尝试
        let terminalPriority = [
            ("iTerm2", executeWithITerm2),
            ("Ghostty", executeWithGhostty),
            ("Kitty", executeWithKitty),
            ("WezTerm", executeWithWezTerm),
            ("Alacritty", executeWithAlacritty),
            ("Terminal", executeWithTerminal)
        ]
        
        for (name, executor) in terminalPriority {
            if executor(command, viewModel) {
                print("成功使用 \(name) 执行命令")
                return true
            }
        }
        
        // 最后降级到直接执行
        return executeDirectly(command: command, in: viewModel)
    }
    
    private func getSystemDefaultTerminal() -> String? {
        // 检测 .sh 文件的默认打开应用
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
    
    private func executeWithFallback(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 降级策略：先尝试系统默认，然后是常见终端，最后直接执行
        return executeWithAutoDetection(command: command, in: viewModel)
    }
    
    private func executeWithTerminal(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 创建 AppleScript 来在 Terminal.app 中执行命令
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        
        guard let script = NSAppleScript(source: appleScript) else {
            return false
        }
        
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        
        if error != nil {
            return false
        }
        
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func executeWithITerm2(command: String, in viewModel: LauncherViewModel) -> Bool {
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
        
        guard let script = NSAppleScript(source: appleScript) else {
            // 如果两个都失败，直接执行命令
            return executeDirectly(command: command, in: viewModel)
        }
        
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        
        if error != nil {
            return executeDirectly(command: command, in: viewModel)
        }
        
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func executeWithGhostty(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 检查 Ghostty 是否已安装
        guard isApplicationInstalled("com.mitchellh.ghostty") else { return false }
        
        // Ghostty 支持 -e 参数来执行命令
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "Ghostty", "--args", "-e", "zsh", "-c", command]
        
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch {
            return false
        }
    }
    
    private func executeWithKitty(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 检查 Kitty 是否已安装
        guard isApplicationInstalled("net.kovidgoyal.kitty") else { return false }
        
        // Kitty 使用 --hold 保持窗口打开，-e 执行命令
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "kitty", "--args", "--hold", "-e", "zsh", "-c", command]
        
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch {
            return false
        }
    }
    
    private func executeWithAlacritty(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 检查 Alacritty 是否已安装
        guard isApplicationInstalled("io.alacritty") else { return false }
        
        // Alacritty 使用 --hold 和 -e 执行命令
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "Alacritty", "--args", "--hold", "-e", "zsh", "-c", command]
        
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch {
            return false
        }
    }
    
    private func executeWithWezTerm(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 检查 WezTerm 是否已安装
        guard isApplicationInstalled("com.github.wez.wezterm") else { return false }
        
        // WezTerm 使用 start -- 来执行命令
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", "WezTerm", "--args", "start", "--", "zsh", "-c", command]
        
        do {
            try process.run()
            viewModel.resetToLaunchMode()
            return true
        } catch {
            return false
        }
    }
    
    private func isApplicationInstalled(_ bundleIdentifier: String) -> Bool {
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
    
    private func executeDirectly(command: String, in viewModel: LauncherViewModel) -> Bool {
        // 作为最后的备选方案，直接在后台执行命令
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
}

// MARK: - 终端模式处理器
@MainActor
class TerminalModeHandler: ModeHandler {
    let prefix = "/t"
    let mode = LauncherMode.terminal
    weak var mainProcessor: MainCommandProcessor?
    
    init(mainProcessor: MainCommandProcessor) {
        self.mainProcessor = mainProcessor
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        if let processor = mainProcessor?.getProcessor(for: .terminal) {
            processor.handleSearch(text: text, in: viewModel)
        }
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        return mainProcessor?.getProcessor(for: .terminal)?.executeAction(at: index, in: viewModel) ?? false
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
