@preconcurrency import Foundation
@testable import LightLauncher

final class HideWindowNotificationRecorder: @unchecked Sendable {
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []
    var requests: [Bool] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observers = [
            notificationCenter.addObserver(
                forName: .hideWindow,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.requests.append(true)
            },
            notificationCenter.addObserver(
                forName: .hideWindowWithoutActivating,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.requests.append(false)
            },
        ]
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    func reset() {
        requests = []
    }
}
