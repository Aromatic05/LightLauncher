import Foundation
import SQLite3

class ArcDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .arc

    static func loadBookmarks() async -> [BrowserItem] {
        let bookmarksPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Arc/User Data/Default/Bookmarks")

        guard BrowserDataUtils.fileExists(at: bookmarksPath.path) else {
            print("Arc bookmarks file not found")
            return []
        }

        do {
            let data = try Data(contentsOf: bookmarksPath)
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
            print("Error loading Arc bookmarks: \(error)")
            return []
        }
    }

    static func loadHistory() async -> [BrowserItem] {
        let historyPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Arc/User Data/Default/History")

        guard BrowserDataUtils.fileExists(at: historyPath.path) else {
            print("Arc history database not found")
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
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                var db: OpaquePointer?
                var historyItems: [BrowserItem] = []

                if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    let query = """
                            SELECT title, url, last_visit_time, visit_count
                            FROM urls
                            WHERE title IS NOT NULL AND title != ''
                            ORDER BY last_visit_time DESC
                            LIMIT 500
                        """

                    var statement: OpaquePointer?
                    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                        while sqlite3_step(statement) == SQLITE_ROW {
                            let title = BrowserDataUtils.safeString(from: statement, at: 0)
                            let url = BrowserDataUtils.safeString(from: statement, at: 1)
                            let lastVisitTime = sqlite3_column_int64(statement, 2)
                            let visitCount = Int(sqlite3_column_int(statement, 3))

                            // Arc 使用与 Chrome 相同的时间戳格式
                            let chromeEpoch = Date(timeIntervalSince1970: -11_644_473_600)
                            let lastVisited = Date(
                                timeInterval: Double(lastVisitTime) / 1_000_000, since: chromeEpoch)

                            let historyItem = BrowserItem(
                                title: title,
                                url: url,
                                type: .history,
                                source: .arc,
                                lastVisited: lastVisited,
                                visitCount: visitCount
                            )
                            historyItems.append(historyItem)
                        }
                    }
                    sqlite3_finalize(statement)
                }
                sqlite3_close(db)

                continuation.resume(returning: historyItems)
            }
        }
    }
}
