import Foundation
import SQLite3

class EdgeDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .edge

    static func loadBookmarks() async -> [BrowserItem] {
        let bookmarksPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Microsoft Edge/Default/Bookmarks")

        guard BrowserDataUtils.fileExists(at: bookmarksPath.path) else {
            print("Edge bookmarks file not found")
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
            print("Error loading Edge bookmarks: \(error)")
            return []
        }
    }

    static func loadHistory() async -> [BrowserItem] {
        let historyPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Microsoft Edge/Default/History")

        guard BrowserDataUtils.fileExists(at: historyPath.path) else {
            print("Edge history database not found")
            return []
        }

        // 检查数据库是否被锁定
        if isDatabaseLocked(at: historyPath.path) {
            return await loadHistoryFromCopy(originalPath: historyPath.path)
        } else {
            return await loadHistoryFromDatabase(at: historyPath.path)
        }
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
                            source: .edge
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

                let openResult = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
                if openResult == SQLITE_OK {
                    let query = """
                            SELECT title, url, last_visit_time, visit_count
                            FROM urls
                            WHERE title IS NOT NULL AND title != ''
                            ORDER BY last_visit_time DESC
                            LIMIT 500
                        """

                    var statement: OpaquePointer?
                    let prepareResult = sqlite3_prepare_v2(db, query, -1, &statement, nil)
                    if prepareResult == SQLITE_OK {
                        while sqlite3_step(statement) == SQLITE_ROW {
                            let title = BrowserDataUtils.safeString(from: statement, at: 0)
                            let url = BrowserDataUtils.safeString(from: statement, at: 1)
                            let lastVisitTime = sqlite3_column_int64(statement, 2)
                            let visitCount = Int(sqlite3_column_int(statement, 3))

                            // Edge 使用与 Chrome 相同的时间戳格式
                            let chromeEpoch = Date(timeIntervalSince1970: -11_644_473_600)
                            let lastVisited = Date(
                                timeInterval: Double(lastVisitTime) / 1_000_000, since: chromeEpoch)

                            let historyItem = BrowserItem(
                                title: title,
                                url: url,
                                type: .history,
                                source: .edge,
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

    private static func loadHistoryFromCopy(originalPath: String) async -> [BrowserItem] {
        let tempDir = NSTemporaryDirectory()
        let tempPath = "\(tempDir)edge_history_temp_\(UUID().uuidString).db"

        do {
            // 尝试复制数据库文件
            try FileManager.default.copyItem(atPath: originalPath, toPath: tempPath)

            // 从临时副本读取数据
            let historyItems = await loadHistoryFromDatabase(at: tempPath)

            // 清理临时文件
            try? FileManager.default.removeItem(atPath: tempPath)

            return historyItems
        } catch {
            print("Edge: Failed to create temporary copy: \(error)")
            return []
        }
    }

    private static func isDatabaseLocked(at path: String) -> Bool {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)

        if result == SQLITE_OK {
            // 尝试执行一个简单的查询来检测锁定
            let testQuery = "SELECT COUNT(*) FROM urls LIMIT 1"
            var statement: OpaquePointer?
            let prepareResult = sqlite3_prepare_v2(db, testQuery, -1, &statement, nil)

            if prepareResult == SQLITE_OK {
                let stepResult = sqlite3_step(statement)
                sqlite3_finalize(statement)
                sqlite3_close(db)
                return stepResult != SQLITE_ROW
            } else {
                sqlite3_close(db)
                return true  // 如果无法准备查询，认为是锁定的
            }
        } else {
            sqlite3_close(db)
            return true  // 如果无法打开，认为是锁定的
        }
    }
}
