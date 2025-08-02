import Foundation
import SwiftUI

// MARK: - 运行中应用信息结构
struct RunningAppInfo: Identifiable, Hashable, DisplayableItem {
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(RunningAppRowView(app: self, isSelected: isSelected, index: index))
    }
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isHidden: Bool
    var title: String { name }
    var subtitle: String? { bundleIdentifier }
    
    var icon: NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == processIdentifier }) {
            return app.icon
        }
        return nil
    }
    var displayName: String { name }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.id == rhs.id
    }

    @MainActor
    func executeAction() -> Bool {
        let result = RunningAppsManager.shared.killApp(self, force: KillModeController.shared.forceKillEnabled)
        if result {
            KillModeController.shared.displayableItems.remove(at: LauncherViewModel.shared.selectedIndex)
        }
        return false // 返回 false 以避免自动隐藏窗口
    }
}