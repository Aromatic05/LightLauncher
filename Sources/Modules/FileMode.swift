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
}

// MARK: - 文件管理器管理类
@MainActor
class FileManager_LightLauncher {
    static let shared = FileManager_LightLauncher()
    
    private init() {}
    
    func getFiles(at path: String) -> [FileItem] {
        let url = URL(fileURLWithPath: path)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var files: [FileItem] = []
            
            // 添加返回上级目录项（除了根目录）
            if path != "/" && path != NSHomeDirectory() {
                let parentURL = url.deletingLastPathComponent()
                files.append(FileItem(
                    name: "..",
                    url: parentURL,
                    isDirectory: true,
                    size: nil,
                    modificationDate: nil
                ))
            }
            
            // 处理目录内容
            for fileURL in contents {
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
                
                if exists {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    
                    files.append(FileItem(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isDirectory: isDirectory.boolValue,
                        size: resourceValues?.fileSize.map { Int64($0) },
                        modificationDate: resourceValues?.contentModificationDate
                    ))
                }
            }
            
            // 排序：目录在前，然后按名称排序
            return files.sorted { file1, file2 in
                if file1.name == ".." { return true }
                if file2.name == ".." { return false }
                if file1.isDirectory != file2.isDirectory {
                    return file1.isDirectory && !file2.isDirectory
                }
                return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
            }
            
        } catch {
            print("Error reading directory: \(error)")
            return []
        }
    }
    
    func filterFiles(_ files: [FileItem], query: String) -> [FileItem] {
        if query.isEmpty {
            return files
        }
        
        return files.filter { file in
            file.name.localizedCaseInsensitiveContains(query) ||
            file.name.localizedLowercase.hasPrefix(query.localizedLowercase)
        }
    }
    
    func openInFinder(_ url: URL) {
        if url.hasDirectoryPath {
            // 如果是目录，在 Finder 中显示该目录
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            // 如果是文件，在 Finder 中选中该文件
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
}

// MARK: - 文件模式控制器
import SwiftUI

@MainActor
final class FileModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = FileModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation
    
    // 1. 身份与元数据
    let mode: LauncherMode = .file
    let prefix: String? = "/o"
    let displayName: String = "File Browser"
    let iconName: String = "folder"
    let placeholder: String = "Browse files or folders..."
    let modeDescription: String? = "Browse your file system"

    @Published var displayableItems: [any DisplayableItem] = []
    
    // 2. 核心逻辑
    func handleInput(arguments: String) {
        if showStartPaths {
            let items = getStartPathItems(query: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            let items = getFileItems(path: currentPath, query: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        if LauncherViewModel.shared.selectedIndex != 0 {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else { return false }
        
        if showStartPaths {
            guard let startPath = self.displayableItems[index] as? FileBrowserStartPath else { return false }
            navigateToDirectory(URL(fileURLWithPath: startPath.path))
            return true // Navigation is an action, but doesn't exit the app
        } else {
            guard let fileItem = self.displayableItems[index] as? FileItem else { return false }
            if fileItem.isDirectory {
                navigateToDirectory(fileItem.url)
                return true // Navigation is an action
            } else {
                let success = NSWorkspace.shared.open(fileItem.url)
                if success {
                    // After opening a file, reset to the initial screen
                    resetToStartScreen()
                }
                return success
            }
        }
    }

    // 3. 生命周期与UI
    func cleanup() {
        self.displayableItems = []
        // Crucially, reset the internal state to its default
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
    }
    
    func makeContentView() -> AnyView {
        // This view logic remains the same
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(FileCommandInputView(currentPath: currentPath))
        }
    }

    func getHelpText() -> [String] {
        return [
            "Browse files and folders",
            "Enter to open files or navigate into folders",
            "Type to filter the current list"
        ]
    }

    // MARK: - Internal State & Helper Methods
    
    @Published private var showStartPaths: Bool = true
    @Published private var currentPath: String = NSHomeDirectory()
    
    func navigateToDirectory(_ url: URL) {
        self.showStartPaths = false
        self.currentPath = url.path
        // Use the main input handler to load the new directory's contents
        self.handleInput(arguments: "")
    }

    func resetToStartScreen() {
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
        self.handleInput(arguments: "")
    }

    private func getStartPathItems(query: String) -> [FileBrowserStartPath] {
        let allPaths = ConfigManager.shared.getFileBrowserStartPaths().map { path in
            FileBrowserStartPath(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
        }
        if query.isEmpty {
            return allPaths
        }
        return allPaths.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func getFileItems(path: String, query: String) -> [FileItem] {
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        return FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
    }

    func openInFinder() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
