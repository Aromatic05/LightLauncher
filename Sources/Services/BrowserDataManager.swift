import Foundation
import SQLite3
import AppKit

// MARK: - 浏览器数据项
struct BrowserItem: Identifiable, Hashable, DisplayableItem {
    let id = UUID()
    let title: String
    let url: String
    let type: BrowserItemType
    let source: BrowserType
    let lastVisited: Date?
    let visitCount: Int
    // 新增：用于自定义显示
    let subtitle: String?
    let iconName: String?
    let actionHint: String?
    var icon: NSImage? { nil }
    // 兼容 DisplayableItem 协议
    var displaySubtitle: String? { subtitle ?? url }
    
    init(title: String, url: String, type: BrowserItemType, source: BrowserType = .safari, lastVisited: Date? = nil, visitCount: Int = 0, subtitle: String? = nil, iconName: String? = nil, actionHint: String? = nil) {
        self.title = title
        self.url = url
        self.type = type
        self.source = source
        self.lastVisited = lastVisited
        self.visitCount = visitCount
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionHint = actionHint
    }
}

enum BrowserItemType {
    case bookmark
    case history
    case input // 新增：当前输入项
}

enum BrowserType: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"
    case arc = "Arc"
    
    var displayName: String {
        return self.rawValue
    }
    
    var isInstalled: Bool {
        let appPaths = [
            "/Applications/\(self.rawValue).app",
            "/System/Applications/\(self.rawValue).app",
            "/Applications/Microsoft Edge.app" // Edge 特殊处理
        ]
        
        switch self {
        case .edge:
            return FileManager.default.fileExists(atPath: "/Applications/Microsoft Edge.app")
        default:
            return appPaths.contains { FileManager.default.fileExists(atPath: $0) }
        }
    }
}

// MARK: - 浏览器数据管理器
@MainActor
class BrowserDataManager {
    static let shared = BrowserDataManager()
    
    private var bookmarks: [BrowserItem] = []
    private var historyItems: [BrowserItem] = []
    private var lastLoadTime: Date?
    private var enabledBrowsers: Set<BrowserType> = [.safari] // 默认只启用 Safari
    
    private init() {
        enabledBrowsers = ConfigManager.shared.getEnabledBrowsers()
    }
    
    func setEnabledBrowsers(_ browsers: Set<BrowserType>) {
        enabledBrowsers = browsers
        // 清除缓存，强制重新加载
        lastLoadTime = nil
    }
    
    func getEnabledBrowsers() -> Set<BrowserType> {
        return enabledBrowsers
    }
    
    func loadBrowserData() {        
        // 避免频繁加载，缓存5分钟
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 {
            return
        }
        
        Task.detached {
            var allBookmarks: [BrowserItem] = []
            var allHistory: [BrowserItem] = []
            
            // 加载所有启用的浏览器数据
            for browser in await self.enabledBrowsers {
                // await print(self.enabledBrowsers)
                if browser.isInstalled {
                    let (bookmarks, history) = await Self.loadBrowserData(for: browser)
                    allBookmarks.append(contentsOf: bookmarks)
                    allHistory.append(contentsOf: history)
                }
            }
            
            // 合并和去重
            let uniqueBookmarks = await Self.removeDuplicates(from: allBookmarks)
            let uniqueHistory = await Self.removeDuplicates(from: allHistory)
            
            // print("🔍 Final result: \(uniqueBookmarks.count) unique bookmarks, \(uniqueHistory.count) unique history items")
            
            await MainActor.run { [weak self] in
                self?.bookmarks = uniqueBookmarks
                self?.historyItems = uniqueHistory
                self?.lastLoadTime = Date()
            }
        }
    }
    
    func searchBrowserData(query: String) -> [BrowserItem] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [BrowserItem] = []
        
        // 优先匹配URL的项目（书签和历史记录混合）
        let urlMatchingBookmarks = bookmarks.filter { bookmark in
            bookmark.url.lowercased().contains(queryLower)
        }
        
        let urlMatchingHistory = historyItems.filter { item in
            item.url.lowercased().contains(queryLower)
        }.sorted { item1, item2 in
            // 按访问次数和最后访问时间排序
            if item1.visitCount != item2.visitCount {
                return item1.visitCount > item2.visitCount
            }
            return (item1.lastVisited ?? Date.distantPast) > (item2.lastVisited ?? Date.distantPast)
        }
        
        // 然后匹配标题的项目（书签和历史记录混合）
        let titleMatchingBookmarks = bookmarks.filter { bookmark in
            !bookmark.url.lowercased().contains(queryLower) &&
            bookmark.title.lowercased().contains(queryLower)
        }
        
        let titleMatchingHistory = historyItems.filter { item in
            !item.url.lowercased().contains(queryLower) &&
            item.title.lowercased().contains(queryLower)
        }.sorted { item1, item2 in
            // 按访问次数和最后访问时间排序
            if item1.visitCount != item2.visitCount {
                return item1.visitCount > item2.visitCount
            }
            return (item1.lastVisited ?? Date.distantPast) > (item2.lastVisited ?? Date.distantPast)
        }
        
        // 按优先级合并结果：
        // 1. URL匹配的书签（最高优先级）
        results.append(contentsOf: urlMatchingBookmarks)
        // 2. URL匹配的历史记录（高优先级）
        results.append(contentsOf: Array(urlMatchingHistory.prefix(10)))
        // 3. 标题匹配的书签（中等优先级）
        results.append(contentsOf: titleMatchingBookmarks)
        // 4. 标题匹配的历史记录（低优先级）
        results.append(contentsOf: Array(titleMatchingHistory.prefix(5)))
        
        return results
    }
    
    func getDefaultBrowserItems(limit: Int = 10) -> [BrowserItem] {
        var results: [BrowserItem] = []
        
        // 先添加一些书签
        let recentBookmarks = Array(bookmarks.prefix(limit / 2))
        results.append(contentsOf: recentBookmarks)
        
        // 再添加最近访问的历史记录
        let recentHistory = historyItems
            .sorted { item1, item2 in
                if item1.visitCount != item2.visitCount {
                    return item1.visitCount > item2.visitCount
                }
                return (item1.lastVisited ?? Date.distantPast) > (item2.lastVisited ?? Date.distantPast)
            }
            .prefix(limit - results.count)
        
        results.append(contentsOf: recentHistory)
        
        return Array(results.prefix(limit))
    }
    
    // MARK: - 多浏览器数据加载
    private static func loadBrowserData(for browser: BrowserType) async -> ([BrowserItem], [BrowserItem]) {
        switch browser {
        case .safari:
            let bookmarks = await SafariDataLoader.loadBookmarks()
            let history = await SafariDataLoader.loadHistory()
            return (bookmarks, history)
        case .chrome:
            let bookmarks = await ChromeDataLoader.loadBookmarks()
            let history = await ChromeDataLoader.loadHistory()
            return (bookmarks, history)
        case .edge:
            let bookmarks = await EdgeDataLoader.loadBookmarks()
            let history = await EdgeDataLoader.loadHistory()
            return (bookmarks, history)
        case .firefox:
            let bookmarks = await FirefoxDataLoader.loadBookmarks()
            let history = await FirefoxDataLoader.loadHistory()
            return (bookmarks, history)
        case .arc:
            let bookmarks = await ArcDataLoader.loadBookmarks()
            let history = await ArcDataLoader.loadHistory()
            return (bookmarks, history)
        }
    }
    
    private static func removeDuplicates(from items: [BrowserItem]) -> [BrowserItem] {
        var seen = Set<String>()
        var result: [BrowserItem] = []
        
        for item in items {
            let key = "\(item.url)|\(item.type)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        
        return result
    }
}
