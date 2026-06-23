import Foundation

@MainActor
protocol LauncherWindowRouting {
    func hideMainWindow(shouldActivatePreviousApp: Bool)
}

struct NotificationCenterWindowRouter: LauncherWindowRouting {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func hideMainWindow(shouldActivatePreviousApp: Bool) {
        let notificationName: Notification.Name =
            shouldActivatePreviousApp ? .hideWindow : .hideWindowWithoutActivating
        notificationCenter.post(name: notificationName, object: nil)
    }
}
