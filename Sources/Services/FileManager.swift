import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - 文件管理器管理类
@MainActor
class FileManager_LightLauncher {
    static let shared = FileManager_LightLauncher()
    
    private init() {}
    
    func getFiles(at path: String) -> [FileItem] {
        // 检查文件访问权限
        guard PermissionManager.shared.checkFileBrowsingPermissions() else {
            // 如果没有权限，返回空数组并显示权限请求
            Task { @MainActor in
                PermissionManager.shared.promptPermissionGuide(for: .fileAccess)
            }
            return []
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: []  // 不跳过隐藏文件
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
            
            // 如果读取失败，可能是权限问题，显示更具体的错误信息
            Task { @MainActor in
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "无法访问目录"
                alert.informativeText = "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。\n\n错误详情：\(error.localizedDescription)"
                alert.addButton(withTitle: "检查权限")
                alert.addButton(withTitle: "确定")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    PermissionManager.shared.promptPermissionGuide(for: .fileAccess)
                }
            }
            
            return []
        }
    }
    
    func filterFiles(_ files: [FileItem], query: String) -> [FileItem] {
        if query.isEmpty {
            return files
        }
        
        return files.filter { file in
            // 改进过滤逻辑，支持更精确的匹配
            let fileName = file.name.localizedLowercase
            let queryLower = query.localizedLowercase
            
            // 1. 完全匹配
            if fileName == queryLower {
                return true
            }
            
            // 2. 前缀匹配
            if fileName.hasPrefix(queryLower) {
                return true
            }
            
            // 3. 包含匹配
            if fileName.contains(queryLower) {
                return true
            }
            
            return false
        }
    }
    
    func openInFinder(_ url: URL) {
        // 检查文件访问权限
        guard PermissionManager.shared.checkFileBrowsingPermissions() else {
            Task { @MainActor in
                PermissionManager.shared.withPermission(.fileAccess) {
                    // 权限获得后重新执行
                    self.openInFinder(url)
                }
            }
            return
        }
        
        if url.hasDirectoryPath {
            // 如果是目录，在 Finder 中显示该目录
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            // 如果是文件，在 Finder 中选中该文件
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
}