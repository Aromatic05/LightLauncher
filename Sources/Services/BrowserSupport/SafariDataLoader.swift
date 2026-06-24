import Foundation

class SafariDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .safari
    private static let fileAccess = FileAccessService.shared
    private static let database = DatabaseService.shared

    static func loadBookmarks() async -> [BrowserItem] {
        let bookmarksPath = BrowserDataSupport.homeDirectory.appendingPathComponent(
            "Library/Safari/Bookmarks.plist")

        guard BrowserDataSupport.fileExists(at: bookmarksPath) else {
            Logger.shared.info("Safari bookmarks file not found")
            return []
        }

        do {
            let data = try fileAccess.readData(from: bookmarksPath)
            guard
                let plist = try PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil) as? [String: Any],
                let children = plist["Children"] as? [[String: Any]]
            else {
                return []
            }

            return parseBookmarkChildren(children)
        } catch {
            Logger.shared.error("Error loading Safari bookmarks: \(error)")
            return []
        }
    }

    static func loadHistory() async -> [BrowserItem] {
        let historyPath = BrowserDataSupport.homeDirectory.appendingPathComponent(
            "Library/Safari/History.db")

        guard BrowserDataSupport.fileExists(at: historyPath) else {
            Logger.shared.info("Safari history database not found")
            return []
        }

        return await loadHistoryFromDatabase(at: historyPath)
    }

    // MARK: - Private Methods

    private static func parseBookmarkChildren(_ children: [[String: Any]]) -> [BrowserItem] {
        var bookmarks: [BrowserItem] = []

        for child in children {
            if let type = child["WebBookmarkType"] as? String {
                if type == "WebBookmarkTypeLeaf",
                    let uriDict = child["URIDictionary"] as? [String: Any],
                    let title = uriDict["title"] as? String,
                    let urlString = child["URLString"] as? String,
                    !urlString.isEmpty
                {
                    let bookmark = BrowserItem(
                        title: title.isEmpty ? urlString : title,
                        url: urlString,
                        type: .bookmark,
                        source: .safari
                    )
                    bookmarks.append(bookmark)
                } else if type == "WebBookmarkTypeList",
                    let subChildren = child["Children"] as? [[String: Any]]
                {
                    // 递归解析文件夹中的书签
                    bookmarks.append(contentsOf: parseBookmarkChildren(subChildren))
                }
            }
        }

        return bookmarks
    }

    private static func loadHistoryFromDatabase(at url: URL) async -> [BrowserItem] {
        let query = """
                SELECT hv.title, hi.url, hv.visit_time, hi.visit_count
                FROM history_visits hv
                JOIN history_items hi ON hv.history_item = hi.id
                WHERE hv.title IS NOT NULL AND hv.title != ''
                ORDER BY hv.visit_time DESC
                LIMIT 500
            """
        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        return await database.readRows(at: url, query: query) { statement in
            let visitTime = database.double(from: statement, at: 2)
            return BrowserItem(
                title: database.string(from: statement, at: 0),
                url: database.string(from: statement, at: 1),
                type: .history,
                source: .safari,
                lastVisited: Date(timeInterval: visitTime, since: referenceDate),
                visitCount: database.int(from: statement, at: 3)
            )
        }
    }
}
