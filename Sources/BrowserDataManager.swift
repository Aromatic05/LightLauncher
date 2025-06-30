import Foundation
import SQLite3

// MARK: - 浏览器数据项
struct BrowserItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: String
    let type: BrowserItemType
    let source: BrowserType
    let lastVisited: Date?
    let visitCount: Int
    
    init(title: String, url: String, type: BrowserItemType, source: BrowserType = .safari, lastVisited: Date? = nil, visitCount: Int = 0) {
        self.title = title
        self.url = url
        self.type = type
        self.source = source
        self.lastVisited = lastVisited
        self.visitCount = visitCount
    }
}

enum BrowserItemType {
    case bookmark
    case history
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
    
    private init() {}
    
    func setEnabledBrowsers(_ browsers: Set<BrowserType>) {
        enabledBrowsers = browsers
        // 清除缓存，强制重新加载
        lastLoadTime = nil
    }
    
    func getEnabledBrowsers() -> Set<BrowserType> {
        return enabledBrowsers
    }
    
    func loadBrowserData() {
        print("🔍 BrowserDataManager: loadBrowserData called")
        print("🔍 Enabled browsers: \(enabledBrowsers)")
        
        // 避免频繁加载，缓存5分钟
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 {
            print("🔍 Using cached data (last load: \(lastLoad))")
            return
        }
        
        Task.detached {
            var allBookmarks: [BrowserItem] = []
            var allHistory: [BrowserItem] = []
            
            // 加载所有启用的浏览器数据
            for browser in await self.enabledBrowsers {
                print("🔍 Checking browser: \(browser.rawValue), installed: \(browser.isInstalled)")
                if browser.isInstalled {
                    let (bookmarks, history) = await Self.loadBrowserData(for: browser)
                    print("🔍 Loaded from \(browser.rawValue): \(bookmarks.count) bookmarks, \(history.count) history items")
                    allBookmarks.append(contentsOf: bookmarks)
                    allHistory.append(contentsOf: history)
                }
            }
            
            // 合并和去重
            let uniqueBookmarks = await Self.removeDuplicates(from: allBookmarks)
            let uniqueHistory = await Self.removeDuplicates(from: allHistory)
            
            print("🔍 Final result: \(uniqueBookmarks.count) unique bookmarks, \(uniqueHistory.count) unique history items")
            
            await MainActor.run { [weak self] in
                self?.bookmarks = uniqueBookmarks
                self?.historyItems = uniqueHistory
                self?.lastLoadTime = Date()
            }
        }
    }
    
    func searchBrowserData(query: String) -> [BrowserItem] {
        let queryLower = query.lowercased()
        var results: [BrowserItem] = []
        
        // 搜索书签（优先级更高）
        let matchingBookmarks = bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(queryLower) ||
            bookmark.url.lowercased().contains(queryLower)
        }
        
        // 搜索历史记录
        let matchingHistory = historyItems.filter { item in
            item.title.lowercased().contains(queryLower) ||
            item.url.lowercased().contains(queryLower)
        }.sorted { item1, item2 in
            // 按访问次数和最后访问时间排序
            if item1.visitCount != item2.visitCount {
                return item1.visitCount > item2.visitCount
            }
            return (item1.lastVisited ?? Date.distantPast) > (item2.lastVisited ?? Date.distantPast)
        }
        
        // 合并结果：书签在前，历史记录在后
        results.append(contentsOf: matchingBookmarks)
        results.append(contentsOf: Array(matchingHistory.prefix(10))) // 限制历史记录数量
        
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
