import Foundation

class FirefoxDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .firefox
    private static let fileAccess = FileAccessService.shared
    private static let database = DatabaseService.shared

    static func loadBookmarks() async -> [BrowserItem] {
        let profilesPath = BrowserDataUtils.homeDirectory.appendingPathComponent(
            "Library/Application Support/Firefox/Profiles")

        guard BrowserDataUtils.fileExists(at: profilesPath.path) else {
                Logger.shared.info("Firefox profiles directory not found")
            return []
        }

        // 查找默认配置文件
        do {
            let profiles = try fileAccess.contentsOfDirectory(atPath: profilesPath.path)
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
            let profiles = try fileAccess.contentsOfDirectory(atPath: profilesPath.path)
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
        let query = """
                SELECT b.title, p.url
                FROM moz_bookmarks b
                JOIN moz_places p ON b.fk = p.id
                WHERE b.type = 1 AND b.title IS NOT NULL AND b.title != ''
                ORDER BY b.dateAdded DESC
                LIMIT 500
            """
        return await database.readRows(at: URL(fileURLWithPath: path), query: query) { statement in
            BrowserItem(
                title: database.string(from: statement, at: 0),
                url: database.string(from: statement, at: 1),
                type: .bookmark,
                source: .firefox
            )
        }
    }

    private static func loadHistoryFromDatabase(at path: String) async -> [BrowserItem] {
        let query = """
                SELECT title, url, last_visit_date, visit_count
                FROM moz_places
                WHERE title IS NOT NULL AND title != '' AND visit_count > 0
                ORDER BY last_visit_date DESC
                LIMIT 500
            """
        return await database.readRows(at: URL(fileURLWithPath: path), query: query) { statement in
            let lastVisitDate = database.int64(from: statement, at: 2)
            return BrowserItem(
                title: database.string(from: statement, at: 0),
                url: database.string(from: statement, at: 1),
                type: .history,
                source: .firefox,
                lastVisited: Date(timeIntervalSince1970: Double(lastVisitDate) / 1_000_000),
                visitCount: database.int(from: statement, at: 3)
            )
        }
    }
}
