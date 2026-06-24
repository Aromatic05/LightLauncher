import Foundation

// MARK: - 浏览器数据加载协议
protocol BrowserDataLoader {
    static func loadBookmarks() async -> [BrowserItem]
    static func loadHistory() async -> [BrowserItem]
    static var browserType: BrowserType { get }
}

protocol ChromiumBrowserDataLoader: BrowserDataLoader {
    static var bookmarksRelativePath: String { get }
    static var historyRelativePath: String { get }
    static var shouldCopyHistoryDatabase: Bool { get }
}

extension ChromiumBrowserDataLoader {
    static var shouldCopyHistoryDatabase: Bool { false }

    static func loadBookmarks() async -> [BrowserItem] {
        return BrowserDataSupport.loadChromiumBookmarks(
            relativePath: bookmarksRelativePath,
            source: browserType
        )
    }

    static func loadHistory() async -> [BrowserItem] {
        return await BrowserDataSupport.loadChromiumHistory(
            relativePath: historyRelativePath,
            source: browserType,
            copyToTemporary: shouldCopyHistoryDatabase
        )
    }
}

// MARK: - 通用辅助方法
enum BrowserDataSupport {
    private static let fileAccess = FileAccessService.shared
    private static let database = DatabaseService.shared
    private static let chromiumHistoryQuery = """
        SELECT title, url, last_visit_time, visit_count
        FROM urls
        WHERE title IS NOT NULL AND title != ''
        ORDER BY last_visit_time DESC
        LIMIT 500
        """
    private static let chromeEpoch = Date(timeIntervalSince1970: -11_644_473_600)

    static var homeDirectory: URL {
        return fileAccess.homeDirectory
    }

    static func fileExists(at url: URL) -> Bool {
        return fileAccess.fileExists(at: url)
    }

    static func loadChromiumBookmarks(relativePath: String, source: BrowserType) -> [BrowserItem] {
        let bookmarksURL = homeDirectory.appendingPathComponent(relativePath)

        guard fileExists(at: bookmarksURL) else {
            Logger.shared.info("\(source.displayName) bookmarks file not found")
            return []
        }

        do {
            let data = try fileAccess.readData(from: bookmarksURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let roots = json["roots"] as? [String: Any]
            else {
                return []
            }

            return roots.values.compactMap { $0 as? [String: Any] }.flatMap {
                parseChromiumBookmarkFolder($0, source: source)
            }
        } catch {
            Logger.shared.error("Error loading \(source.displayName) bookmarks: \(error)")
            return []
        }
    }

    static func loadChromiumHistory(
        relativePath: String,
        source: BrowserType,
        copyToTemporary: Bool = false
    ) async -> [BrowserItem] {
        let historyURL = homeDirectory.appendingPathComponent(relativePath)

        guard fileExists(at: historyURL) else {
            Logger.shared.info("\(source.displayName) history database not found")
            return []
        }

        return await database.readRows(
            at: historyURL,
            query: chromiumHistoryQuery,
            copyToTemporary: copyToTemporary
        ) { statement in
            let title = database.string(from: statement, at: 0)
            let url = database.string(from: statement, at: 1)
            let lastVisitTime = database.int64(from: statement, at: 2)
            let visitCount = database.int(from: statement, at: 3)
            let lastVisited = Date(
                timeInterval: Double(lastVisitTime) / 1_000_000,
                since: chromeEpoch
            )

            return BrowserItem(
                title: title,
                url: url,
                type: .history,
                source: source,
                lastVisited: lastVisited,
                visitCount: visitCount
            )
        }
    }

    static func parseChromiumBookmarkFolder(_ folder: [String: Any], source: BrowserType)
        -> [BrowserItem]
    {
        guard let children = folder["children"] as? [[String: Any]] else {
            return []
        }

        return children.flatMap { child -> [BrowserItem] in
            guard let type = child["type"] as? String else { return [] }

            if type == "url",
                let name = child["name"] as? String,
                let url = child["url"] as? String
            {
                return [
                    BrowserItem(
                        title: name,
                        url: url,
                        type: .bookmark,
                        source: source
                    )
                ]
            }

            if type == "folder" {
                return parseChromiumBookmarkFolder(child, source: source)
            }

            return []
        }
    }

    static func findFirefoxPlacesDatabaseURL() -> URL? {
        let profilesURL = homeDirectory.appendingPathComponent(
            "Library/Application Support/Firefox/Profiles")

        guard fileExists(at: profilesURL) else {
            Logger.shared.info("Firefox profiles directory not found")
            return nil
        }

        do {
            let profiles = try fileAccess.contentsOfDirectory(atPath: profilesURL.path)
            let profile = profiles.first {
                $0.hasSuffix(".default-release") || $0.hasSuffix(".default")
            }

            guard let profile else { return nil }

            let placesURL = profilesURL.appendingPathComponent(profile).appendingPathComponent(
                "places.sqlite")
            return fileExists(at: placesURL) ? placesURL : nil
        } catch {
            Logger.shared.error("Error accessing Firefox profiles: \(error)")
            return nil
        }
    }
}
