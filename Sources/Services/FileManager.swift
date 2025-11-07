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
        
        let originalURL = URL(fileURLWithPath: path)

        // 优先解析符号链接：如果用户传入的是符号链接，尝试跟随到目标路径。
        // 注意：resolvingSymlinksInPath 会返回解析后的 URL，但如果目标不存在或不可访问，后续的 fileExists/contentsOfDirectory 会失败。
    let url = originalURL.resolvingSymlinksInPath()

        // 如果解析后路径不存在（可能是坏的符号链接），给出更明确的提示并返回空
        if !FileManager.default.fileExists(atPath: url.path) {
            // 如果解析后路径不存在，但原始路径本身存在（可能指向一个坏链接），给出针对符号链接的提示
            if FileManager.default.fileExists(atPath: originalURL.path) {
                Task { @MainActor in
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = "符号链接目标不存在"
                    alert.informativeText = "路径 '\(path)' 是一个符号链接，但其目标不存在或不可访问。请检查符号链接或目标路径。"
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                }
                return []
            }

            // 原始路径本身也不存在 — 保持原有错误处理风格
            Task { @MainActor in
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "无法访问目录"
                alert.informativeText = "访问 '\(path)' 时出现错误。这可能是权限问题或目录不存在。"
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
            return []
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey],
                options: []  // 不跳过隐藏文件
            )
            
            var files: [FileItem] = []
            
            // 添加返回上级目录项（除了根目录）
            if url.path != "/" && url.path != NSHomeDirectory() {
                // 为返回上级目录展示父目录（基于解析后的目标路径）
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
                // 尝试获取资源信息，优先判断是否目录并处理符号链接（但继续列出项以便用户看到它）
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

                if exists {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey])

                    // 如果当前项是一个符号链接并且它指向目录，您可能希望在 UI 上把它当成目录处理；这里不强制跟随目标，只是标记为目录（当目标为目录时）
                    var finalIsDirectory = isDirectory.boolValue
                    if let isSymlink = resourceValues?.isSymbolicLink, isSymlink {
                        // 尝试解析符号链接目标并判断目标是否为目录
                        let resolved = fileURL.resolvingSymlinksInPath()
                        var resolvedIsDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &resolvedIsDir) {
                            finalIsDirectory = resolvedIsDir.boolValue
                        }
                    }

                    files.append(FileItem(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isDirectory: finalIsDirectory,
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