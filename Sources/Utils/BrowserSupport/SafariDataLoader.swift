import Foundation
import SQLite3

class SafariDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .safari
    
    static func loadBookmarks() async -> [BrowserItem] {
        let bookmarksPath = BrowserDataUtils.homeDirectory.appendingPathComponent("Library/Safari/Bookmarks.plist")
        
        guard BrowserDataUtils.fileExists(at: bookmarksPath.path) else {
            print("Safari bookmarks file not found")
            return []
        }
        
        do {
            let data = try Data(contentsOf: bookmarksPath)
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let children = plist["Children"] as? [[String: Any]] else {
                return []
            }
            
            return parseBookmarkChildren(children)
        } catch {
            print("Error loading Safari bookmarks: \(error)")
            return []
        }
    }
    
    static func loadHistory() async -> [BrowserItem] {
        let historyPath = BrowserDataUtils.homeDirectory.appendingPathComponent("Library/Safari/History.db")
        
        guard BrowserDataUtils.fileExists(at: historyPath.path) else {
            print("Safari history database not found")
            return []
        }
        
        return await loadHistoryFromDatabase(at: historyPath.path)
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
                   !urlString.isEmpty {
                    let bookmark = BrowserItem(
                        title: title.isEmpty ? urlString : title,
                        url: urlString,
                        type: .bookmark,
                        source: .safari
                    )
                    bookmarks.append(bookmark)
                } else if type == "WebBookmarkTypeList",
                          let subChildren = child["Children"] as? [[String: Any]] {
                    // 递归解析文件夹中的书签
                    bookmarks.append(contentsOf: parseBookmarkChildren(subChildren))
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
                
                // 使用只读模式打开数据库
                if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    let query = """
                        SELECT hv.title, hi.url, hv.visit_time, hi.visit_count
                        FROM history_visits hv
                        JOIN history_items hi ON hv.history_item = hi.id
                        WHERE hv.title IS NOT NULL AND hv.title != ''
                        ORDER BY hv.visit_time DESC
                        LIMIT 500
                    """
                    
                    var statement: OpaquePointer?
                    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                        while sqlite3_step(statement) == SQLITE_ROW {
                            let title = BrowserDataUtils.safeString(from: statement, at: 0)
                            let url = BrowserDataUtils.safeString(from: statement, at: 1)
                            let visitTime = sqlite3_column_double(statement, 2)
                            let visitCount = Int(sqlite3_column_int(statement, 3))
                            
                            // Safari 时间戳是从2001年1月1日开始的秒数
                            let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
                            let lastVisited = Date(timeInterval: visitTime, since: referenceDate)
                            
                            let historyItem = BrowserItem(
                                title: title,
                                url: url,
                                type: .history,
                                source: .safari,
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
