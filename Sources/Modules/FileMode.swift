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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileBrowserStartPath, rhs: FileBrowserStartPath) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 文件模式数据
struct FileModeData: ModeData {
    let files: [FileItem]
    let currentPath: String
    
    var count: Int { files.count }
    
    func item(at index: Int) -> Any? {
        guard index >= 0 && index < files.count else { return nil }
        return files[index]
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
@MainActor
class FileModeController: NSObject, ModeStateController, ObservableObject {
    var displayableItems: [any DisplayableItem] = []
    @Published var showStartPaths: Bool = true
    @Published var currentPath: String = NSHomeDirectory()
    var prefix: String? { "/o" }
    // 可显示项插槽
    // var displayableItems: [any DisplayableItem] {
    //     if showStartPaths {
    //         return fileBrowserStartPaths.map { $0 as any DisplayableItem }
    //     } else {
    //         return currentFiles.map { $0 as any DisplayableItem }
    //     }
    // }
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/o")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        showStartPaths = true
        self.displayableItems = getStartPathItems(query: "").map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        if showStartPaths {
            self.displayableItems = getStartPathItems(query: text).map { $0 as any DisplayableItem }
        } else {
            self.displayableItems = getFileItems(path: currentPath, query: text).map { $0 as any DisplayableItem }
        }
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        if showStartPaths {
            guard index >= 0 && index < self.displayableItems.count else { return false }
            guard let startPath = self.displayableItems[index] as? FileBrowserStartPath else { return false }
            navigateToDirectory(URL(fileURLWithPath: startPath.path), viewModel: viewModel)
            return true
        } else {
            guard index >= 0 && index < self.displayableItems.count else { return false }
            guard let fileItem = self.displayableItems[index] as? FileItem else { return false }
            if fileItem.isDirectory {
                navigateToDirectory(fileItem.url, viewModel: viewModel)
                return true
            } else {
                let success = NSWorkspace.shared.open(fileItem.url)
                if success {
                    enterMode(with: "", viewModel: viewModel) // 返回起始界面
                }
                return success
            }
        }
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /o 前缀或切换到其他模式时退出
        return !text.hasPrefix("/o")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        self.displayableItems = []
    }
    // 获取起始路径项
    private func getStartPathItems(query: String) -> [FileBrowserStartPath] {
        let allPaths = ConfigManager.shared.getFileBrowserStartPaths().map { path in
            FileBrowserStartPath(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
        }
        if query.isEmpty {
            return allPaths
        }
        return allPaths.filter { startPath in
            startPath.title.localizedCaseInsensitiveContains(query) ||
            startPath.path.localizedCaseInsensitiveContains(query)
        }
    }
    // 获取文件项
    private func getFileItems(path: String, query: String) -> [FileItem] {
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        return FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
    }
    // 跳转目录
    func navigateToDirectory(_ url: URL, viewModel: LauncherViewModel) {
        showStartPaths = false
        currentPath = url.path
        self.displayableItems = getFileItems(path: url.path, query: "").map { $0 as any DisplayableItem }
        viewModel.selectedIndex = 0
    }
    func openInFinder(_ url: URL) {
        if url.hasDirectoryPath {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }

    // 其它便捷属性和方法
    var currentFiles: [FileItem] {
        displayableItems.compactMap { $0 as? FileItem }
    }
    var fileBrowserStartPaths: [FileBrowserStartPath] {
        displayableItems.compactMap { $0 as? FileBrowserStartPath }
    }
    func getFileItem(at index: Int) -> FileItem? {
        currentFiles.indices.contains(index) ? currentFiles[index] : nil
    }
    func getStartPath(at index: Int) -> FileBrowserStartPath? {
        fileBrowserStartPaths.indices.contains(index) ? fileBrowserStartPaths[index] : nil
    }
    // 直接跳转目录
    func jumpToDirectory(_ url: URL) {
        showStartPaths = false
        currentPath = url.path
        self.displayableItems = getFileItems(path: url.path, query: "").map { $0 as any DisplayableItem }
    }
    func showStartPathsList() {
        showStartPaths = true
        self.displayableItems = getStartPathItems(query: "").map { $0 as any DisplayableItem }
    }
    func updateFileResults(path: String) {
        jumpToDirectory(URL(fileURLWithPath: path))
    }

    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        if !self.displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: viewModel))
        } else {
            return AnyView(FileCommandInputView(currentPath: NSHomeDirectory()))
        }
    }

    static func getHelpText() -> [String] {
        return [
            "Browse files and folders starting from home directory",
            "Press Enter to open files or navigate folders",
            "Press Space to open current folder in Finder",
            "Delete /o prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}
