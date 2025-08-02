import AppKit
import Foundation
import SQLite3
import SwiftUI

// MARK: - 浏览器数据管理器 (已优化)
@MainActor
class BrowserDataManager {
    static let shared = BrowserDataManager()

    private var allItems: [PreScoredItem] = []
    private var lastLoadTime: Date?
    private var enabledBrowsers: Set<BrowserType>

    private let URL_SEGMENT_MAX_LENGTH = 35
    // 新增：定义分层搜索的阈值
    private let SHORT_QUERY_THRESHOLD = 2

    private init() {
        enabledBrowsers = ConfigManager.shared.getEnabledBrowsers()
    }

    func setEnabledBrowsers(_ browsers: Set<BrowserType>) {
        enabledBrowsers = browsers
        lastLoadTime = nil
    }

    func getEnabledBrowsers() -> Set<BrowserType> {
        return enabledBrowsers
    }

    func loadBrowserData() {
        // 检查是否有完全磁盘访问权限
        guard PermissionManager.shared.checkBrowserDataPermissions() else {
            // 如果没有权限，显示权限请求
            Task { @MainActor in
                PermissionManager.shared.withBrowserDataPermission {
                    // 权限获得后重新调用
                    self.loadBrowserData()
                }
            }
            return
        }

        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 { return }

        Task.detached(priority: .utility) {
            var allBookmarks: [BrowserItem] = []
            var allHistory: [BrowserItem] = []

            for browser in await self.enabledBrowsers where browser.isInstalled {
                let (bookmarks, history) = await Self.loadBrowserData(for: browser)
                allBookmarks.append(contentsOf: bookmarks)
                allHistory.append(contentsOf: history)
            }

            let preScoredItems = await self.prepareAndPreScoreItems(
                bookmarks: allBookmarks, history: allHistory)

            await MainActor.run { [weak self] in
                self?.allItems = preScoredItems
                self?.lastLoadTime = Date()
            }
        }
    }

    private struct SearchWeights {
        static let urlMatch: Double = 10.0
        static let titleMatch: Double = 6.0
        static let prefixMatchBonus: Double = 5.0  // 稍微提高前缀匹配奖励
        static let isBookmarkBonus: Double = 3.0
        static let visitCountMultiplier: Double = 1.2
        static let recencyScore: Double = 5.0
        static let recencyDecayDays: Double = 30.0
        static let hostMatchBonus: Double = 8.0
    }

    private struct PreScoredItem {
        let item: BrowserItem
        let baseScore: Double
        let isBookmark: Bool
        let lowercasedTitle: String
        let searchableUrl: String
    }

    private func createSearchableUrl(from urlString: String) -> String {
        guard let urlComponents = URLComponents(string: urlString) else {
            return urlString.lowercased()
        }
        let host = urlComponents.host ?? ""
        let pathSegments = urlComponents.path.split(separator: "/")
        let filteredPath = pathSegments.filter {
            return $0.count < URL_SEGMENT_MAX_LENGTH || !$0.contains(where: \.isNumber)
        }.joined(separator: "/")
        return (host + "/" + filteredPath).lowercased()
    }

    private func prepareAndPreScoreItems(bookmarks: [BrowserItem], history: [BrowserItem])
        -> [PreScoredItem]
    {
        var uniqueItems: [String: BrowserItem] = [:]
        for bookmark in bookmarks { uniqueItems[bookmark.url] = bookmark }
        for historyItem in history where uniqueItems[historyItem.url] == nil {
            uniqueItems[historyItem.url] = historyItem
        }

        return uniqueItems.values.map { item in
            let isBookmark = item.type == .bookmark
            var baseScore: Double = 0.0
            baseScore += log(Double(item.visitCount + 1)) * SearchWeights.visitCountMultiplier
            if let lastVisited = item.lastVisited {
                let daysAgo =
                    Calendar.current.dateComponents([.day], from: lastVisited, to: Date()).day
                    ?? Int.max
                if Double(daysAgo) < SearchWeights.recencyDecayDays {
                    baseScore +=
                        SearchWeights.recencyScore
                        * (1.0 - (Double(daysAgo) / SearchWeights.recencyDecayDays))
                }
            }
            return PreScoredItem(
                item: item,
                baseScore: baseScore,
                isBookmark: isBookmark,
                lowercasedTitle: item.title.lowercased(),
                searchableUrl: createSearchableUrl(from: item.url)
            )
        }
    }

    func searchBrowserData(query: String) -> [BrowserItem] {
        loadBrowserData()

        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if queryLower.isEmpty { return [] }

        var searchResults: [(item: BrowserItem, score: Double)]

        // 核心优化：根据查询长度选择不同策略
        if queryLower.count <= SHORT_QUERY_THRESHOLD {
            // --- 快速路径：仅限前缀匹配，保证极速响应 ---
            searchResults = allItems.compactMap {
                preScoredItem -> (item: BrowserItem, score: Double)? in
                var queryScore: Double = 0.0

                if preScoredItem.searchableUrl.hasPrefix(queryLower) {
                    queryScore += SearchWeights.urlMatch + SearchWeights.hostMatchBonus
                }

                if preScoredItem.lowercasedTitle.hasPrefix(queryLower) {
                    queryScore += SearchWeights.titleMatch
                }

                if queryScore == 0 { return nil }

                let finalScore =
                    preScoredItem.baseScore + queryScore + SearchWeights.prefixMatchBonus
                return (item: preScoredItem.item, score: finalScore)
            }
        } else {
            // --- 完整路径：执行高精度加权搜索 ---
            searchResults = allItems.compactMap {
                preScoredItem -> (item: BrowserItem, score: Double)? in
                var queryScore: Double = 0.0

                if preScoredItem.searchableUrl.contains(queryLower) {
                    queryScore += SearchWeights.urlMatch
                    if preScoredItem.searchableUrl.hasPrefix(queryLower) {
                        queryScore += SearchWeights.hostMatchBonus
                    }
                }

                if preScoredItem.lowercasedTitle.contains(queryLower) {
                    queryScore += SearchWeights.titleMatch
                    if preScoredItem.lowercasedTitle.hasPrefix(queryLower) {
                        queryScore += SearchWeights.prefixMatchBonus
                    }
                }

                if queryScore == 0 { return nil }

                var finalScore = preScoredItem.baseScore + queryScore
                if preScoredItem.isBookmark {
                    finalScore += SearchWeights.isBookmarkBonus
                }
                return (item: preScoredItem.item, score: finalScore)
            }
        }

        return searchResults.sorted { $0.score > $1.score }.map { $0.item }
    }

    func getDefaultBrowserItems(limit: Int = 10) -> [BrowserItem] {
        loadBrowserData()

        return
            allItems
            .sorted { $0.baseScore > $1.baseScore }
            .prefix(limit)
            .map { $0.item }
    }

    private static func loadBrowserData(for browser: BrowserType) async -> (
        [BrowserItem], [BrowserItem]
    ) {
        switch browser {
        case .safari:
            return (await SafariDataLoader.loadBookmarks(), await SafariDataLoader.loadHistory())
        case .chrome:
            return (await ChromeDataLoader.loadBookmarks(), await ChromeDataLoader.loadHistory())
        case .edge:
            return (await EdgeDataLoader.loadBookmarks(), await EdgeDataLoader.loadHistory())
        case .firefox:
            return (await FirefoxDataLoader.loadBookmarks(), await FirefoxDataLoader.loadHistory())
        case .arc:
            return (await ArcDataLoader.loadBookmarks(), await ArcDataLoader.loadHistory())
        }
    }
}
