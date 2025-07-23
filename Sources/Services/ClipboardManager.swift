import AppKit
import SwiftUI

/// 剪切板历史记录项
enum ClipboardItem: Codable, Equatable, DisplayableItem {
    case text(String)
    case file(URL)
    
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    enum ItemType: String, Codable {
        case text, file
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .file:
            let value = try container.decode(URL.self, forKey: .value)
            self = .file(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let url):
            try container.encode(ItemType.file, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(ClipItemRowView(item: self, isSelected: isSelected, index: index))
    }
    var id: UUID {
        switch self {
        case .text(let str):
            return UUID(uuidString: str.hash.description) ?? UUID()
        case .file(let url):
            return UUID(uuidString: url.path.hash.description) ?? UUID()
        }
    }
    var title: String {
        switch self {
        case .text(let str):
            return str
        case .file(let url):
            return url.lastPathComponent
        }
    }
    var subtitle: String? {
        switch self {
        case .text:
            return nil
        case .file(let url):
            return url.path
        }
    }
    var icon: NSImage? {
        switch self {
        case .text:
            return nil
        case .file:
            return nil
        }
    }
}

/// 剪切板历史记录管理器
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
    private let saveInterval: TimeInterval = 10.0 // 可调整保存间隔（秒）
    private let historyDirectory: URL
    private let historyFileURL: URL
    
    private init(maxHistoryCount: Int = 50) {
        self.maxHistoryCount = maxHistoryCount
        let docDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/LightLauncher", isDirectory: true)
        self.historyDirectory = docDir
        self.historyFileURL = docDir.appendingPathComponent("clipboard_history.json")
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
    
    /// 开始监听剪切板变化
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { [self] in
                await self.checkPasteboard()
            }
        }
    }
    
    /// 停止监听
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 检查剪切板内容是否有变化
    private func checkPasteboard() {
        if pasteboard.changeCount != changeCount {
            changeCount = pasteboard.changeCount
            // 优先处理文件
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
                for url in fileURLs {
                    addToHistory(.file(url))
                }
            } else if let newString = pasteboard.string(forType: .string), !newString.isEmpty {
                addToHistory(.text(newString))
            }
        }
    }
    
    /// 添加到历史记录
    private func addToHistory(_ item: ClipboardItem) {
        if history.first != item {
            history.insert(item, at: 0)
            if history.count > maxHistoryCount {
                history = Array(history.prefix(maxHistoryCount))
            }
            dirty = true
        }
    }
    
    /// 获取全部历史
    func getHistory() -> [ClipboardItem] {
        return history
    }
    
    /// 清空历史
    func clearHistory() {
        history.removeAll()
        dirty = true
    }
    
    /// 删除指定历史项
    func removeHistory(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        dirty = true
    }
    
    /// 删除指定下标的历史项
    func removeItem(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        dirty = true
    }
    
    /// 加载历史记录
    private func loadHistory() {
        do {
            try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: historyFileURL.path) {
                let data = try Data(contentsOf: historyFileURL)
                let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
                self.history = Array(decoded.prefix(maxHistoryCount))
            }
        } catch {
            print("剪切板历史加载失败: \(error)")
        }
    }
    
    /// 保存历史记录
    private func saveHistory() {
        do {
            try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(history.prefix(maxHistoryCount)))
            try data.write(to: historyFileURL)
        } catch {
            print("剪切板历史保存失败: \(error)")
        }
    }
    
    private func startSaveTimer() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { [self] in
                await self.periodicSaveHistory()
            }
        }
    }
    
    @MainActor
    private func stopSaveTimer() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    private func periodicSaveHistory() {
        if dirty {
            saveHistory()
            dirty = false
        }
    }
    
    private func forceSaveHistory() {
        saveHistory()
        dirty = false
    }
}
