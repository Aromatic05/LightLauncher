import Foundation
import AppKit

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

// MARK: - LauncherViewModel 扩展
extension LauncherViewModel {
    // 兼容旧接口，转发到 StateController
    var showStartPaths: Bool {
        (activeController as? FileModeController)?.showStartPaths ?? false
    }
    var currentFiles: [FileItem] {
        (activeController as? FileModeController)?.currentFiles ?? []
    }
    var fileBrowserStartPaths: [FileBrowserStartPath] {
        (activeController as? FileModeController)?.fileBrowserStartPaths ?? []
    }
    var currentPath: String {
        (activeController as? FileModeController)?.currentPath ?? NSHomeDirectory()
    }
    func getFileItem(at index: Int) -> FileItem? {
        currentFiles.indices.contains(index) ? currentFiles[index] : nil
    }
    func getStartPath(at index: Int) -> FileBrowserStartPath? {
        fileBrowserStartPaths.indices.contains(index) ? fileBrowserStartPaths[index] : nil
    }
    func switchToFileMode() {
        if let controller = activeController as? FileModeController {
            controller.enterMode(with: "", viewModel: self)
        }
    }
    func filterFiles(query: String) {
        if let controller = activeController as? FileModeController {
            controller.handleInput(query, viewModel: self)
        }
    }
    func navigateToDirectory(_ url: URL) {
        (activeController as? FileModeController)?.navigateToDirectory(url)
    }
    func showFileBrowserStartPaths() {
        if let controller = activeController as? FileModeController {
            controller.enterMode(with: "", viewModel: self)
        }
    }
    func loadFileBrowserStartPaths() {
        (activeController as? FileModeController)?.loadFileBrowserStartPaths()
    }
    func updateFileResults(path: String) {
        (activeController as? FileModeController)?.navigateToDirectory(URL(fileURLWithPath: path))
    }
}

// MARK: - 文件模式控制器
@MainActor
class FileModeController: NSObject, ModeStateController {
    @Published var currentFiles: [FileItem] = []
    @Published var fileBrowserStartPaths: [FileBrowserStartPath] = []
    @Published var showStartPaths: Bool = true
    @Published var currentPath: String = NSHomeDirectory()
    var prefix: String? { "/o" }
    
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        if showStartPaths {
            return fileBrowserStartPaths.map { $0 as any DisplayableItem }
        } else {
            return currentFiles.map { $0 as any DisplayableItem }
        }
    }
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/o")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        showStartPaths = true
        currentFiles = []
        loadFileBrowserStartPaths()
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        if showStartPaths {
            let allPaths = ConfigManager.shared.getFileBrowserStartPaths().map { path in
                FileBrowserStartPath(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
            }
            fileBrowserStartPaths = allPaths.filter { startPath in
                startPath.title.localizedCaseInsensitiveContains(text) ||
                startPath.path.localizedCaseInsensitiveContains(text)
            }
        } else {
            let allFiles = FileManager_LightLauncher.shared.getFiles(at: currentPath)
            currentFiles = FileManager_LightLauncher.shared.filterFiles(allFiles, query: text)
        }
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        if showStartPaths {
            guard index >= 0 && index < fileBrowserStartPaths.count else { return false }
            let startPath = fileBrowserStartPaths[index]
            navigateToDirectory(URL(fileURLWithPath: startPath.path))
            return true
        } else {
            guard index >= 0 && index < currentFiles.count else { return false }
            let fileItem = currentFiles[index]
            if fileItem.isDirectory {
                navigateToDirectory(fileItem.url)
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
        currentFiles = []
        fileBrowserStartPaths = []
    }
    func loadFileBrowserStartPaths() {
        let paths = ConfigManager.shared.getFileBrowserStartPaths()
        fileBrowserStartPaths = paths.map { path in
            FileBrowserStartPath(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
        }
    }
    func navigateToDirectory(_ url: URL) {
        showStartPaths = false
        currentPath = url.path
        currentFiles = FileManager_LightLauncher.shared.getFiles(at: url.path)
    }
    func openInFinder(_ url: URL) {
        if url.hasDirectoryPath {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
}

// MARK: - 文件命令建议提供器
struct FileCommandSuggestionProvider: CommandSuggestionProvider {
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
