import Foundation
import AppKit

// MARK: - 文件管理器命令处理器
@MainActor
class FileCommandProcessor: CommandProcessor {
    func canHandle(command: String) -> Bool {
        return command == "/o"
    }
    
    func process(command: String, in viewModel: LauncherViewModel) -> Bool {
        guard command == "/o" else { return false }
        viewModel.switchToFileMode()
        return true
    }
    
    func handleSearch(text: String, in viewModel: LauncherViewModel) {
        // 解析文件路径输入
        let cleanText = text.hasPrefix("/o ") ? 
            String(text.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines) : 
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty {
            // 如果没有输入，显示当前目录
            viewModel.updateFileResults(path: viewModel.currentPath)
        } else {
            // 根据输入过滤文件
            viewModel.filterFiles(query: cleanText)
        }
    }
    
    func executeAction(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        guard viewModel.mode == .file else { return false }
        
        // 获取选中的文件项
        guard let fileItem = viewModel.getFileItem(at: index) else { return false }
        
        return openFileItem(fileItem, in: viewModel)
    }
    
    private func openFileItem(_ fileItem: FileItem, in viewModel: LauncherViewModel) -> Bool {
        if fileItem.isDirectory {
            // 如果是目录，进入该目录
            viewModel.navigateToDirectory(fileItem.url)
            return false // 不关闭窗口，继续浏览
        } else {
            // 如果是文件，用默认方式打开
            let success = NSWorkspace.shared.open(fileItem.url)
            if success {
                viewModel.resetToLaunchMode()
            }
            return success
        }
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
    func switchToFileMode() {
        mode = .file
        // 从家目录开始
        currentPath = NSHomeDirectory()
        updateFileResults(path: currentPath)
        selectedIndex = 0
    }
    
    func updateFileResults(path: String) {
        currentPath = path
        currentFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        selectedIndex = 0
    }
    
    func filterFiles(query: String) {
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: currentPath)
        currentFiles = FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
        selectedIndex = 0
    }
    
    func navigateToDirectory(_ url: URL) {
        updateFileResults(path: url.path)
    }
    
    func getFileItem(at index: Int) -> FileItem? {
        guard index >= 0 && index < currentFiles.count else { return nil }
        return currentFiles[index]
    }
    
    func openSelectedFileInFinder() {
        guard let fileItem = getFileItem(at: selectedIndex) else { return }
        FileManager_LightLauncher.shared.openInFinder(fileItem.url)
    }
}
