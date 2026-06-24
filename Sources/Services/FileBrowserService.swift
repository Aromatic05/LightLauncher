import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - 文件浏览服务
@MainActor
final class FileBrowserService {
    static let shared = FileBrowserService()
    private let fileAccess = FileAccessService.shared
    private let alertService = AlertService.shared
    private let permissionManager = PermissionManager.shared
    private let permissionPromptService = PermissionPromptService.shared

    private init() {}

    func getFiles(at path: String) -> [FileItem] {
        guard ensureFileBrowsingPermission() else { return [] }

        let originalURL = URL(fileURLWithPath: path)

        // 优先解析符号链接：如果用户传入的是符号链接，尝试跟随到目标路径。
        // 注意：resolvingSymlinksInPath 会返回解析后的 URL，但如果目标不存在或不可访问，后续的 fileExists/contentsOfDirectory 会失败。
        let url = fileAccess.resolveSymlinks(for: originalURL)

        // 如果解析后路径不存在（可能是坏的符号链接），给出更明确的提示并返回空
        if !fileAccess.fileExists(at: url) {
            // 如果解析后路径不存在，但原始路径本身存在（可能指向一个坏链接），给出针对符号链接的提示
            if fileAccess.fileExists(at: originalURL) {
                alertService.showBrokenSymlinkError(forPath: path)
                return []
            }

            // 原始路径本身也不存在 — 保持原有错误处理风格
            alertService.showDirectoryAccessError(forPath: path)
            return []
        }

        do {
            return try loadFiles(at: url)

        } catch {
            Logger.shared.error("Error reading directory: \(error)", owner: self)

            // 如果读取失败，可能是权限问题，显示更具体的错误信息
            alertService.showDirectoryAccessError(forPath: path, error: error)
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
        guard ensureFileBrowsingPermission() else { return }

        if url.hasDirectoryPath {
            // 如果是目录，在 Finder 中显示该目录
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            // 如果是文件，在 Finder 中选中该文件
            NSWorkspace.shared.selectFile(
                url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }

    private func ensureFileBrowsingPermission() -> Bool {
        guard permissionManager.checkFileBrowsingPermissions() else {
            permissionPromptService.prompt(for: .fileAccess)
            return false
        }
        return true
    }

    private func loadFiles(at url: URL) throws -> [FileItem] {
        let contents = try fileAccess.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey,
            ],
            options: []
        )

        var files = parentDirectoryItem(for: url).map { [$0] } ?? []
        files += contents.compactMap(buildFileItem(from:))

        return files.sorted { file1, file2 in
            if file1.name == ".." { return true }
            if file2.name == ".." { return false }
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory && !file2.isDirectory
            }
            return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
        }
    }

    private func parentDirectoryItem(for url: URL) -> FileItem? {
        guard url.path != "/" else { return nil }

        return FileItem(
            name: "..",
            url: url.deletingLastPathComponent(),
            isDirectory: true,
            size: nil,
            modificationDate: nil
        )
    }

    private func buildFileItem(from fileURL: URL) -> FileItem? {
        var isDirectory: ObjCBool = false
        guard fileAccess.itemExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        let resourceValues = try? fileURL.resourceValues(forKeys: [
            .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey,
        ])

        return FileItem(
            name: fileURL.lastPathComponent,
            url: fileURL,
            isDirectory: resolvedDirectoryFlag(
                for: fileURL,
                resourceValues: resourceValues,
                fallback: isDirectory.boolValue
            ),
            size: resourceValues?.fileSize.map { Int64($0) },
            modificationDate: resourceValues?.contentModificationDate
        )
    }

    private func resolvedDirectoryFlag(
        for fileURL: URL,
        resourceValues: URLResourceValues?,
        fallback: Bool
    ) -> Bool {
        guard resourceValues?.isSymbolicLink == true else { return fallback }

        let resolved = fileAccess.resolveSymlinks(for: fileURL)
        var resolvedIsDirectory: ObjCBool = false
        guard fileAccess.itemExists(atPath: resolved.path, isDirectory: &resolvedIsDirectory) else {
            return fallback
        }
        return resolvedIsDirectory.boolValue
    }
}
