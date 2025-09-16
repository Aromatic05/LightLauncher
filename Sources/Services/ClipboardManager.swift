import AppKit
import SwiftUI

@MainActor
class ClipboardManager {
    static let shared = ClipboardManager()

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private(set) var history: [ClipboardItem] = []
    private let maxHistoryCount: Int
    private var timer: Timer?
    private var saveTimer: Timer?
    private var dirty: Bool = false
    private let saveInterval: TimeInterval = 10.0  // 可调整保存间隔（秒）
    private let historyDirectory: URL
    private let historyFileURL: URL
    private let archiveDirectory: URL
    private let archiveFilePrefix = "archive_"
    private let archiveFileExtension = "json"

    private init(maxHistoryCount: Int = 50) {
        self.maxHistoryCount = maxHistoryCount
        let docDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Documents/LightLauncher", isDirectory: true)
        self.historyDirectory = docDir
        self.historyFileURL = docDir.appendingPathComponent("clipboard_history.json")
        self.archiveDirectory = docDir.appendingPathComponent("archives", isDirectory: true)
        self.changeCount = pasteboard.changeCount
        loadHistory()
        startMonitoring()
        startSaveTimer()
    }

    deinit {
        Task { [self] in
            await stopMonitoring()
            await forceSaveHistory()
            await stopSaveTimer()
        }
    }

    // MARK: - Monitoring

    /// 开始监听剪切板变化
    func startMonitoring() {
        // 检查剪切板权限（虽然通常不需要特殊权限，但保持一致性）
        guard PermissionManager.shared.checkClipboardPermissions() else {
            Task { @MainActor in
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = "剪切板功能"
                alert.informativeText = "剪切板历史记录功能已启用。如果遇到问题，请检查应用权限设置。"
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { [self] in
                await self.checkPasteboard()
            }
        }
    }

    /// 停止监听
    func stopMonitoring() async {
        timer?.invalidate()
        timer = nil
    }

    /// 检查剪切板内容是否有变化
    private func checkPasteboard() async {
        if pasteboard.changeCount != changeCount {
            changeCount = pasteboard.changeCount
            // 优先处理文件
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)
                as? [URL], !fileURLs.isEmpty
            {
                for url in fileURLs {
                    addToHistory(.file(url))
                }
            } else if let newString = pasteboard.string(forType: .string), !newString.isEmpty {
                addToHistory(.text(newString))
            }
        }
    }

    // MARK: - History management

    /// 添加到历史记录
    private func addToHistory(_ item: ClipboardItem) {
        if history.first != item {
            history.insert(item, at: 0)

            if history.count > maxHistoryCount {
                // 将溢出的旧记录（最末端）归档到磁盘，而不是丢弃
                let overflow = Array(history.suffix(from: maxHistoryCount))
                // 保留最新的 maxHistoryCount 条在内存中
                history = Array(history.prefix(maxHistoryCount))
                // 将 overflow 归档（按页）
                archiveOverflowItems(overflow)
            }
            dirty = true
        }
    }

    /// 获取全部当前内存中的历史（只包含最新的 maxHistoryCount 条）
    func getHistory() -> [ClipboardItem] {
        return history
    }

    /// 清空内存历史（注意：这不会删除磁盘上的归档。用户必须显式删除归档）
    func clearHistory() {
        history.removeAll()
        dirty = true
    }

    /// 清空所有历史（包括磁盘归档）——仅当用户显式调用时才执行
    func clearAllIncludingArchives() {
        history.removeAll()
        dirty = true
        do {
            if FileManager.default.fileExists(atPath: historyFileURL.path) {
                try FileManager.default.removeItem(at: historyFileURL)
            }
            if FileManager.default.fileExists(atPath: archiveDirectory.path) {
                try FileManager.default.removeItem(at: archiveDirectory)
            }
            try FileManager.default.createDirectory(
                at: archiveDirectory, withIntermediateDirectories: true)
        } catch {
            print("删除所有历史（包括归档）失败：\(error)")
        }
    }

    /// 删除指定历史项（仅当前内存中的项）
    func removeHistory(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        dirty = true
    }

    /// 删除指定下标的历史项（同 removeHistory）
    func removeItem(at index: Int) {
        removeHistory(at: index)
    }

    // MARK: - Archive handling

    /// 将一组溢出项追加归档到磁盘，按页保存，每页最多 maxHistoryCount 项
    private func archiveOverflowItems(_ items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(
                at: archiveDirectory, withIntermediateDirectories: true)
        } catch {
            print("创建归档目录失败: \(error)")
            return
        }

        var remaining = items

        // 尝试向最后一页追加（如果存在且未满）
        if let lastPageIndex = findLastArchivePageIndex(),
            let lastPageURL = archiveFileURL(forPage: lastPageIndex),
            let data = try? Data(contentsOf: lastPageURL),
            var decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        {
            let space = maxHistoryCount - decoded.count
            if space > 0 {
                let take = Array(remaining.prefix(space))
                decoded.append(contentsOf: take)
                // 保存回最后一页
                do {
                    let encoded = try JSONEncoder().encode(decoded)
                    try encoded.write(to: lastPageURL)
                } catch {
                    print("向最后归档页追加失败: \(error)")
                }
                if remaining.count <= space {
                    return
                } else {
                    remaining = Array(remaining.dropFirst(space))
                }
            }
        }

        // 创建新的归档页直到没有剩余项
        while !remaining.isEmpty {
            let take = Array(remaining.prefix(maxHistoryCount))
            remaining = Array(remaining.dropFirst(take.count))
            // 新的归档文件使用时间戳和序号，便于排序与追溯：archive_<timestamp>_<seq>.json
            let newIndex = (findLastArchivePageIndex() ?? 0) + 1
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            let fileName = "\(archiveFilePrefix)\(ts)_\(newIndex).\(archiveFileExtension)"
            let url = archiveDirectory.appendingPathComponent(fileName)
            do {
                let encoded = try JSONEncoder().encode(take)
                try encoded.write(to: url)
            } catch {
                print("创建新的归档页失败: \(error)")
            }
        }
    }

    /// 返回归档目录中最后一页的数字索引（1-based），如果没有归档则返回 nil
    private func findLastArchivePageIndex() -> Int? {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                atPath: archiveDirectory.path)
            let pageNums = contents.compactMap { fileName -> Int? in
                // 期望格式: archive_<timestamp>_<seq>.json
                guard fileName.hasPrefix(archiveFilePrefix),
                    fileName.hasSuffix(".\(archiveFileExtension)")
                else {
                    return nil
                }
                let base = fileName.replacingOccurrences(of: ".\(archiveFileExtension)", with: "")
                let parts = base.split(separator: "_")
                // parts: ["archive", "<timestamp>", "<seq>"]
                if parts.count >= 3, let seq = Int(parts[2]) {
                    return seq
                }
                return nil
            }
            return pageNums.max()
        } catch {
            // 目录可能不存在
            return nil
        }
    }

    /// 生成归档页文件 URL（page 从 1 开始）
    ///
    /// 因为文件名包含时间戳与序号（archive_<timestamp>_<seq>.json），
    /// 这里通过扫描目录并匹配序号来找到对应页的文件 URL。
    private func archiveFileURL(forPage page: Int) -> URL? {
        guard page >= 1 else { return nil }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: archiveDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for url in fileURLs {
                let name = url.lastPathComponent
                guard
                    name.hasPrefix(archiveFilePrefix) && name.hasSuffix(".\(archiveFileExtension)")
                else { continue }
                let base = name.replacingOccurrences(of: ".\(archiveFileExtension)", with: "")
                let parts = base.split(separator: "_")
                if parts.count >= 3, let seq = Int(parts[2]), seq == page {
                    return url
                }
            }
        } catch {
            // ignore and return nil
        }
        return nil
    }

    /// 获取归档页数量
    func getArchivePageCount() -> Int {
        return findLastArchivePageIndex() ?? 0
    }

    /// 加载指定归档页（page 从 1 开始），如果不存在则返回空数组
    func loadArchivePage(_ page: Int) -> [ClipboardItem] {
        guard page >= 1, let url = archiveFileURL(forPage: page),
            FileManager.default.fileExists(atPath: url.path)
        else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            return decoded
        } catch {
            print("加载归档页 \(page) 失败: \(error)")
            return []
        }
    }

    /// 删除指定归档页（用户主动操作）
    func removeArchivePage(_ page: Int) {
        guard page >= 1, let url = archiveFileURL(forPage: page) else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                // 重命名后续页以保持连续编号（可选，但便于管理）
                normalizeArchivePageIndices(startingFrom: page + 1)
            }
        } catch {
            print("删除归档页 \(page) 失败: \(error)")
        }
    }

    /// 将后续页向前移动 1 位以保持连续编号（删除某页后调用）
    ///
    /// 归档文件名包含时间戳与序号，例如：archive_<timestamp>_<seq>.json
    /// 在移动时保留原始时间戳（便于追溯），只修改序号部分。
    private func normalizeArchivePageIndices(startingFrom startPage: Int) {
        var current = startPage
        while true {
            guard let currentURL = archiveFileURL(forPage: current),
                FileManager.default.fileExists(atPath: currentURL.path)
            else {
                break
            }
            let fileName = currentURL.lastPathComponent
            let base = fileName.replacingOccurrences(of: ".\(archiveFileExtension)", with: "")
            let parts = base.split(separator: "_")
            guard parts.count >= 3 else { break }
            let ts = parts[1]  // timestamp portion
            let targetIndex = current - 1
            // 新文件名：archive_<timestamp>_<targetIndex>.json
            let targetName = "\(archiveFilePrefix)\(ts)_\(targetIndex).\(archiveFileExtension)"
            let targetURL = archiveDirectory.appendingPathComponent(targetName)
            do {
                // 如果目标已存在（理论上不该出现），先移除
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                try FileManager.default.moveItem(at: currentURL, to: targetURL)
            } catch {
                print("重命名归档页 \(current) -> \(targetIndex) 失败: \(error)")
                break
            }
            current += 1
        }
    }

    // MARK: - Persistence

    /// 加载历史记录（只加载前 maxHistoryCount 条），归档页单独按需加载
    private func loadHistory() {
        do {
            try FileManager.default.createDirectory(
                at: historyDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: archiveDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: historyFileURL.path) {
                let data = try Data(contentsOf: historyFileURL)
                let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
                // 仅保留前 maxHistoryCount 条到内存
                self.history = Array(decoded.prefix(maxHistoryCount))
            } else {
                self.history = []
            }
        } catch {
            print("剪切板历史加载失败: \(error)")
            self.history = []
        }
    }

    /// 保存当前内存中的历史记录（只保存前 maxHistoryCount 条）
    private func saveHistory() {
        do {
            try FileManager.default.createDirectory(
                at: historyDirectory, withIntermediateDirectories: true)
            let toSave = Array(history.prefix(maxHistoryCount))
            let data = try JSONEncoder().encode(toSave)
            try data.write(to: historyFileURL)
        } catch {
            print("剪切板历史保存失败: \(error)")
        }
    }

    private func startSaveTimer() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            Task { [self] in
                await self.periodicSaveHistory()
            }
        }
    }

    @MainActor
    private func stopSaveTimer() async {
        saveTimer?.invalidate()
        saveTimer = nil
    }

    private func periodicSaveHistory() async {
        if dirty {
            saveHistory()
            dirty = false
        }
    }

    private func forceSaveHistory() async {
        saveHistory()
        dirty = false
    }

    // MARK: - Utilities for debugging / export

    /// 导出所有历史记录（包括归档）到一个数组 —— 此操作会读取所有归档页（可能较大）
    func exportAllHistoryIncludingArchives() -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        // 先当前内存中的（最新）
        result.append(contentsOf: history)
        // 然后按页顺序加载归档（从第一页开始）
        let pageCount = getArchivePageCount()
        if pageCount > 0 {
            for page in 1...pageCount {
                let pageItems = loadArchivePage(page)
                result.append(contentsOf: pageItems)
            }
        }
        return result
    }

    /// 将指定归档页中的某个元素删除（用户操作）
    func removeArchiveItem(page: Int, at index: Int) {
        guard page >= 1, let url = archiveFileURL(forPage: page),
            FileManager.default.fileExists(atPath: url.path)
        else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            guard decoded.indices.contains(index) else { return }
            decoded.remove(at: index)
            // 如果该页为空，删除该文件并 normalize
            if decoded.isEmpty {
                try FileManager.default.removeItem(at: url)
                normalizeArchivePageIndices(startingFrom: page + 1)
            } else {
                let encoded = try JSONEncoder().encode(decoded)
                try encoded.write(to: url)
            }
        } catch {
            print("从归档页删除项失败: \(error)")
        }
    }
}
