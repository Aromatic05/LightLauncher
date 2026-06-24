import Foundation

class FirefoxDataLoader: BrowserDataLoader {
    static let browserType: BrowserType = .firefox
    private static let database = DatabaseService.shared

    static func loadBookmarks() async -> [BrowserItem] {
        guard let placesURL = BrowserDataSupport.findFirefoxPlacesDatabaseURL() else { return [] }
        return await loadBookmarksFromDatabase(at: placesURL)
    }

    static func loadHistory() async -> [BrowserItem] {
        guard let placesURL = BrowserDataSupport.findFirefoxPlacesDatabaseURL() else { return [] }
        return await loadHistoryFromDatabase(at: placesURL)
    }

    // MARK: - Private Methods

    private static func loadBookmarksFromDatabase(at url: URL) async -> [BrowserItem] {
        let query = """
                SELECT b.title, p.url
                FROM moz_bookmarks b
                JOIN moz_places p ON b.fk = p.id
                WHERE b.type = 1 AND b.title IS NOT NULL AND b.title != ''
                ORDER BY b.dateAdded DESC
                LIMIT 500
            """
        return await database.readRows(at: url, query: query) { statement in
            BrowserItem(
                title: database.string(from: statement, at: 0),
                url: database.string(from: statement, at: 1),
                type: .bookmark,
                source: .firefox
            )
        }
    }

    private static func loadHistoryFromDatabase(at url: URL) async -> [BrowserItem] {
        let query = """
                SELECT title, url, last_visit_date, visit_count
                FROM moz_places
                WHERE title IS NOT NULL AND title != '' AND visit_count > 0
                ORDER BY last_visit_date DESC
                LIMIT 500
            """
        return await database.readRows(at: url, query: query) { statement in
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
