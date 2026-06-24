import Foundation
import SwiftUI

// MARK: - 运行中应用信息结构
struct RunningAppInfo: Identifiable, Hashable, DisplayableItem {
    var id: pid_t { processIdentifier }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        erasedRowView(RunningAppRowView(app: self, isSelected: isSelected, index: index))
    }
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isHidden: Bool
    var title: String { name }
    var subtitle: String? { bundleIdentifier }

    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == processIdentifier
        }) {
            return app.icon
        }
        return nil
    }
    var displayName: String { name }

    func hash(into hasher: inout Hasher) {
        hasher.combine(processIdentifier)
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier
            && lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    @MainActor
    func executeAction() -> Bool {
        let result = RunningAppsManager.shared.killApp(
            self, force: KillModeController.shared.forceKillEnabled)
        if result {
            KillModeController.shared.displayableItems.remove(
                at: LauncherViewModel.shared.selectedIndex)
        }
        return false  // 返回 false 以避免自动隐藏窗口
    }
}
