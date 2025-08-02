import Foundation
import AppKit
import SwiftUI

// MARK: - 文件信息结构
struct FileItem: Identifiable, Hashable, DisplayableItem {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?

    // DisplayableItem 协议实现
    var title: String { name }
    var subtitle: String? { url.path }
    
    var icon: NSImage? {
        if isDirectory {
            if #available(macOS 12.0, *) {
                return NSWorkspace.shared.icon(for: .folder)
            } else {
                return NSWorkspace.shared.icon(forFileType: "public.folder")
            }
        } else {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }
    
    var displaySize: String {
        guard let size = size, !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(FileRowView(file: self, isSelected: isSelected, index: index))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    @MainActor
    func executeAction() {
        // 执行文件或目录的打开操作
        if isDirectory {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

// MARK: - 文件浏览器起始路径结构
struct FileBrowserStartPath: Identifiable, Hashable, DisplayableItem {
    let id = UUID()
    let name: String
    let path: String
    
    var icon: NSImage? {
        if #available(macOS 12.0, *) {
            return NSWorkspace.shared.icon(for: .folder)
        } else {
            return NSWorkspace.shared.icon(forFileType: "public.folder")
        }
    }
    
    // 优化后的路径到显示名映射
    static let specialPaths: [(String, String)] = [
        (NSHomeDirectory(), "Home"),
        (NSHomeDirectory() + "/Desktop", "Desktop"),
        (NSHomeDirectory() + "/Downloads", "Downloads"),
        (NSHomeDirectory() + "/Documents", "Documents"),
        ("/Applications", "Applications"),
        ("/", "Root")
    ]
    
    var displayName: String {
        if let match = Self.specialPaths.first(where: { $0.0 == path }) {
            return match.1
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    var displayPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }
    
    // DisplayableItem 协议补充实现
    var title: String { displayName }
    var subtitle: String? { displayPath }
    // 如有其它协议要求属性/方法，请在此补充

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(StartPathRowView(startPath: self, isSelected: isSelected, index: index))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileBrowserStartPath, rhs: FileBrowserStartPath) -> Bool {
        lhs.id == rhs.id
    }
    @MainActor
    func executeAction() -> Bool {
        // 执行打开起始路径的操作
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }
}