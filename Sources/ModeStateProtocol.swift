import AppKit
import Combine
import CryptoKit
import Foundation
import SwiftUI

// MARK: - DisplayableItem 协议
protocol DisplayableItem: Hashable, Identifiable {
    var title: String { get }
    var subtitle: String? { get }
    var icon: NSImage? { get }
    @ViewBuilder @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView
    @MainActor
    func executeAction() -> Bool  // 返回结果确定是否隐藏启动器
}

extension DisplayableItem {
    var icon: NSImage? { nil }

    static func stableID(_ components: Any?...) -> String {
        SHA256.hash(data: Data(components.map(serializeStableIDComponent).joined(separator: "\u{1F}").utf8)
        ).map { String(format: "%02x", $0) }.joined()
    }

    static func loadIcon(named iconName: String?, defaultSystemSymbol: String = "magnifyingglass")
        -> NSImage?
    {
        let fileAccess = FileAccessService.shared
        let defaultIcon = NSImage(systemSymbolName: defaultSystemSymbol, accessibilityDescription: "Default icon")
        guard let iconName, !iconName.isEmpty else { return defaultIcon }
        if iconName.hasPrefix("SF:") {
            return NSImage(systemSymbolName: String(iconName.dropFirst(3)), accessibilityDescription: nil)
        }
        if iconName.hasPrefix("base64:"),
            let data = Data(base64Encoded: String(iconName.dropFirst(7))),
            let image = NSImage(data: data)
        {
            return image
        }

        let userIconsDirectory = fileAccess.homeDirectory.appendingPathComponent(".config/LightLauncher/icons", isDirectory: true)
        let pathName = iconName as NSString
        let baseName = pathName.deletingPathExtension
        let extensionName = pathName.pathExtension
        var candidates: [URL?] = [Bundle.main.url(forResource: baseName, withExtension: extensionName)]
        #if SWIFT_PACKAGE
            candidates.insert(Bundle.module.url(forResource: baseName, withExtension: extensionName), at: 0)
        #endif
        candidates.append(iconName.hasPrefix("/") ? URL(fileURLWithPath: iconName) : (URL(string: iconName)?.isFileURL == true ? URL(string: iconName) : userIconsDirectory.appendingPathComponent(iconName)))
        if extensionName.isEmpty {
            for extensionName in ["png", "jpg", "jpeg", "gif", "pdf"] {
                #if SWIFT_PACKAGE
                    candidates.append(Bundle.module.url(forResource: baseName, withExtension: extensionName))
                #endif
                candidates.append(Bundle.main.url(forResource: baseName, withExtension: extensionName))
                candidates.append(userIconsDirectory.appendingPathComponent(baseName).appendingPathExtension(extensionName))
            }
        }

        for case let url? in candidates {
            if let image = url.isFileURL ? NSImage(contentsOf: url) : ((try? fileAccess.readData(from: url)).flatMap(NSImage.init(data:))) {
                return image
            }
        }
        return defaultIcon
    }

    private static func serializeStableIDComponent(_ component: Any?) -> String {
        guard let component else { return "nil" }
        return "\(String(reflecting: type(of: component))):\(String(reflecting: component))"
    }
}

// MARK: - 模式状态控制器协议（清晰版）
@MainActor
protocol ModeStateController: AnyObject {
    static var shared: Self { get }
    /// 当前模式下所有可显示项（用于 UI 统一绑定）
    var displayableItems: [any DisplayableItem] { get }
    /// 用于通知数据变化的发布者
    var dataDidChange: PassthroughSubject<Void, Never> { get }

    // 新增：模式元信息属性
    var displayName: String { get }
    var commandDisplayName: String { get }
    var iconName: String { get }
    var placeholder: String { get }
    var modeDescription: String? { get }
    /// 模式的触发前缀（如 /k），可选
    var prefix: String? { get }
    var mode: LauncherMode { get }
    var interceptedKeys: Set<KeyEvent> { get }

    // 处理输入：模式激活后每次输入的处理（如搜索、过滤等）
    func handleInput(arguments: String)

    func handle(keyEvent: KeyEvent) -> Bool

    // 模式退出或切换时的清理操作
    func cleanup()

    func makeContentView() -> AnyView

    func getHelpText() -> [String]
}

extension ModeStateController {
    var commandDisplayName: String {
        displayName
    }

    func commandReference(includeTrailingSpace: Bool = false) -> String {
        guard let prefix, !prefix.isEmpty else {
            return ""
        }

        return includeTrailingSpace ? "\(prefix) " : prefix
    }

    func settingsTitle(_ baseTitle: String) -> String {
        guard let prefix, !prefix.isEmpty else {
            return baseTitle
        }

        return "\(baseTitle) (\(prefix))"
    }

    var interceptedKeys: Set<KeyEvent> {
        return []
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        return false
    }

    func makeContentView() -> AnyView {
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyView())
        }
    }

    func getHelpText() -> [String] {
        return []
    }
}
