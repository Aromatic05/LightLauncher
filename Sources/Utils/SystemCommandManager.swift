import AppKit
import Foundation
import SwiftUI

@MainActor
class SystemCommandManager: ObservableObject {
    static let shared = SystemCommandManager()
    @Published var commands: [SystemCommandItem] = []

    init() {
        self.commands = Self.defaultCommands
    }

    static var defaultCommands: [SystemCommandItem] {
        [
            SystemCommandItem(
                title: "lock",
                displayName: "锁屏",
                subtitle: "立即锁定屏幕",
                icon: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil),
                action: {
                    PermissionManager.shared.withAccessibilityPermission {
                        runShell("osascript -e 'tell application \"System Events\" to keystroke \"q\" using {control down, command down}'")
                    }
                }
            ),
            SystemCommandItem(
                title: "shutdown",
                displayName: "关机",
                subtitle: "关闭 Mac 并断电",
                icon: NSImage(systemSymbolName: "power", accessibilityDescription: nil),
                action: {
                    runShell("osascript -e 'tell app \"System Events\" to shut down'")
                }
            ),
            SystemCommandItem(
                title: "restart",
                displayName: "重启",
                subtitle: "重新启动 Mac",
                icon: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil),
                action: {
                    runShell("osascript -e 'tell app \"System Events\" to restart'")
                }
            ),
            SystemCommandItem(
                title: "logout",
                displayName: "注销",
                subtitle: "退出当前用户会话",
                icon: NSImage(systemSymbolName: "person.crop.circle.badge.xmark", accessibilityDescription: nil),
                action: {
                    runShell("osascript -e 'tell app \"System Events\" to log out'")
                }
            ),
            SystemCommandItem(
                title: "emptytrash",
                displayName: "清空废纸篓",
                subtitle: "删除所有废纸篓内容",
                icon: NSImage(systemSymbolName: "trash", accessibilityDescription: nil),
                action: {
                    runShell("osascript -e 'tell app \"Finder\" to empty the trash'")
                }
            ),
            SystemCommandItem(
                title: "volumeup",
                displayName: "音量+",
                subtitle: "增加系统音量",
                icon: NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil),
                action: {
                    adjustVolume(delta: 10)
                }
            ),
            SystemCommandItem(
                title: "volumedown",
                displayName: "音量-",
                subtitle: "降低系统音量",
                icon: NSImage(systemSymbolName: "speaker.wave.1.fill", accessibilityDescription: nil),
                action: {
                    adjustVolume(delta: -10)
                }
            ),
            SystemCommandItem(
                title: "mute",
                displayName: "静音",
                subtitle: "切换静音状态",
                icon: NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: nil),
                action: {
                    runShell("osascript -e 'set volume output muted not (output muted of (get volume settings))'")
                }
            ),
        ]
    }
}

// MARK: - 辅助方法
private func runAppleScript(_ script: String) {
    let appleScript = NSAppleScript(source: script)
    var error: NSDictionary?
    appleScript?.executeAndReturnError(&error)
}

private func runShell(_ command: String) {
    let task = Process()
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    task.launch()
}

private func adjustVolume(delta: Int) {
    let getScript = "output volume of (get volume settings)"
    let appleScript = NSAppleScript(source: getScript)
    var error: NSDictionary?
    let result = appleScript?.executeAndReturnError(&error)
    let current = result?.int32Value ?? 50
    let newVolume = max(0, min(100, current + Int32(delta)))
    let setScript = "set volume output volume \(newVolume)"
    runAppleScript(setScript)
}
