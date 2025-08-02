import AppKit
import SwiftUI

enum BrowserItemType {
    case bookmark
    case history
    case input
}

enum BrowserType: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"
    case arc = "Arc"

    var displayName: String { self.rawValue }
    var isInstalled: Bool {
        let appPaths = [
            "/Applications/\(self.rawValue).app", "/System/Applications/\(self.rawValue).app",
        ]
        switch self {
        case .edge:
            return FileManager.default.fileExists(atPath: "/Applications/Microsoft Edge.app")
        default: return appPaths.contains { FileManager.default.fileExists(atPath: $0) }
        }
    }
}

// MARK: - 浏览器数据项 (无变动)
struct BrowserItem: Identifiable, Hashable, DisplayableItem {
    let id = UUID()
    let title: String
    let url: String
    let type: BrowserItemType
    let source: BrowserType
    let lastVisited: Date?
    let visitCount: Int
    let subtitle: String?
    let iconName: String?
    let actionHint: String?
    var icon: NSImage? { nil }
    var displaySubtitle: String? { subtitle ?? url }

    init(
        title: String, url: String, type: BrowserItemType, source: BrowserType = .safari,
        lastVisited: Date? = nil, visitCount: Int = 0, subtitle: String? = nil,
        iconName: String? = nil, actionHint: String? = nil
    ) {
        self.title = title
        self.url = url
        self.type = type
        self.source = source
        self.lastVisited = lastVisited
        self.visitCount = visitCount
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionHint = actionHint
    }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(BrowserItemRowView(item: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        return WebUtils.openWebURL(self.url)
    }
}
