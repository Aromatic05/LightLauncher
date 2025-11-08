import Foundation
import SQLite3

class FirefoxDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .firefox

    static func loadBookmarks() async -> [BrowserItem] {
        let profilesPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Firefox/Profiles")

        guard BrowserDataUtils.fileExists(at: profilesPath.path) else {
                Logger.shared.info("Firefox profiles directory not found")
            return []
        }

        // 查找默认配置文件
        do {
            let profiles = try FileManager.default.contentsOfDirectory(atPath: profilesPath.path)
            for profile in profiles {
                if profile.hasSuffix(".default-release") || profile.hasSuffix(".default") {
                    let placesPath = profilesPath.appendingPathComponent(profile)
                        .appendingPathComponent("places.sqlite")
                    if BrowserDataUtils.fileExists(at: placesPath.path) {
                        return await loadBookmarksFromDatabase(at: placesPath.path)
                    }
                }
            }
        } catch {
                Logger.shared.error("Error accessing Firefox profiles: \(error)")
        }

        return []
    }

    static func loadHistory() async -> [BrowserItem] {
        let profilesPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Firefox/Profiles")

        guard BrowserDataUtils.fileExists(at: profilesPath.path) else {
                Logger.shared.info("Firefox profiles directory not found")
            return []
        }

        do {
            let profiles = try FileManager.default.contentsOfDirectory(atPath: profilesPath.path)
            for profile in profiles {
                if profile.hasSuffix(".default-release") || profile.hasSuffix(".default") {
                    let placesPath = profilesPath.appendingPathComponent(profile)
                        .appendingPathComponent("places.sqlite")
                    if BrowserDataUtils.fileExists(at: placesPath.path) {
                        return await loadHistoryFromDatabase(at: placesPath.path)
                    }
                }
            }
        } catch {
                Logger.shared.error("Error accessing Firefox profiles: \(error)")
        }

        return []
    }

    // MARK: - Private Methods

    private static func loadBookmarksFromDatabase(at path: String) async -> [BrowserItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                var db: OpaquePointer?
                var bookmarks: [BrowserItem] = []

                if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    let query = """
                            SELECT b.title, p.url
                            FROM moz_bookmarks b
                            JOIN moz_places p ON b.fk = p.id
                            WHERE b.type = 1 AND b.title IS NOT NULL AND b.title != ''
                            ORDER BY b.dateAdded DESC
                            LIMIT 500
                        """

                    var statement: OpaquePointer?
                    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                        while sqlite3_step(statement) == SQLITE_ROW {
                            let title = BrowserDataUtils.safeString(from: statement, at: 0)
                            let url = BrowserDataUtils.safeString(from: statement, at: 1)

                            let bookmark = BrowserItem(
                                title: title,
                                url: url,
                                type: .bookmark,
                                source: .firefox
                            )
                            bookmarks.append(bookmark)
                        }
                    }
                    sqlite3_finalize(statement)
                }
                sqlite3_close(db)

                continuation.resume(returning: bookmarks)
            }
        }
    }

    private static func loadHistoryFromDatabase(at path: String) async -> [BrowserItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                var db: OpaquePointer?
                var historyItems: [BrowserItem] = []

                if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    let query = """
                            SELECT title, url, last_visit_date, visit_count
                            FROM moz_places
                            WHERE title IS NOT NULL AND title != '' AND visit_count > 0
                            ORDER BY last_visit_date DESC
                            LIMIT 500
                        """

                    var statement: OpaquePointer?
                    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                        while sqlite3_step(statement) == SQLITE_ROW {
                            let title = BrowserDataUtils.safeString(from: statement, at: 0)
                            let url = BrowserDataUtils.safeString(from: statement, at: 1)
                            let lastVisitDate = sqlite3_column_int64(statement, 2)
                            let visitCount = Int(sqlite3_column_int(statement, 3))

                            // Firefox 时间戳是微秒数，从1970年开始
                            let lastVisited = Date(
                                timeIntervalSince1970: Double(lastVisitDate) / 1_000_000)

                            let historyItem = BrowserItem(
                                title: title,
                                url: url,
                                type: .history,
                                source: .firefox,
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
