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
        
        // 创建 AppleScript 来在终端中执行命令
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(cleanCommand.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        
        guard let script = NSAppleScript(source: appleScript) else {
            return false
        }
        
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        
        if error != nil {
            // 如果 AppleScript 失败，尝试使用 iTerm2
            return executeWithITerm(command: cleanCommand, in: viewModel)
        }
        
        viewModel.resetToLaunchMode()
        return true
    }
    
    private func executeWithITerm(command: String, in viewModel: LauncherViewModel) -> Bool {
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
