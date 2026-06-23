import Foundation

class ArcDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .arc
    private static let fileAccess = FileAccessService.shared
    private static let database = DatabaseService.shared

    static func loadBookmarks() async -> [BrowserItem] {
        let bookmarksPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Arc/User Data/Default/Bookmarks")

        guard BrowserDataUtils.fileExists(at: bookmarksPath.path) else {
            Logger.shared.info("Arc bookmarks file not found")
            return []
        }

        do {
            let data = try fileAccess.readData(from: bookmarksPath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let roots = json["roots"] as? [String: Any]
            else {
                return []
            }

            var bookmarks: [BrowserItem] = []

            for (_, rootValue) in roots {
                if let root = rootValue as? [String: Any] {
                    bookmarks.append(contentsOf: parseBookmarkFolder(root))
                }
            }

            return bookmarks
        } catch {
            Logger.shared.error("Error loading Arc bookmarks: \(error)")
            return []
        }
    }

    static func loadHistory() async -> [BrowserItem] {
        let historyPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Arc/User Data/Default/History")

        guard BrowserDataUtils.fileExists(at: historyPath.path) else {
            Logger.shared.info("Arc history database not found")
            return []
        }

        return await loadHistoryFromDatabase(at: historyPath.path)
    }

    // MARK: - Private Methods

    private static func parseBookmarkFolder(_ folder: [String: Any]) -> [BrowserItem] {
        var bookmarks: [BrowserItem] = []

        if let children = folder["children"] as? [[String: Any]] {
            for child in children {
                if let type = child["type"] as? String {
                    if type == "url",
                        let name = child["name"] as? String,
                        let url = child["url"] as? String
                    {
                        let bookmark = BrowserItem(
                            title: name,
                            url: url,
                            type: .bookmark,
                            source: .arc
                        )
                        bookmarks.append(bookmark)
                    } else if type == "folder" {
                        bookmarks.append(contentsOf: parseBookmarkFolder(child))
                    }
                }
            }
        }

        return bookmarks
    }

    private static func loadHistoryFromDatabase(at path: String) async -> [BrowserItem] {
        let query = """
                SELECT title, url, last_visit_time, visit_count
                FROM urls
                WHERE title IS NOT NULL AND title != ''
                ORDER BY last_visit_time DESC
                LIMIT 500
            """
        let chromeEpoch = Date(timeIntervalSince1970: -11_644_473_600)
        return await database.readRows(at: URL(fileURLWithPath: path), query: query) { statement in
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
                source: .arc,
                lastVisited: lastVisited,
                visitCount: visitCount
            )
        }
    }
}
