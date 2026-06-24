import Foundation

class EdgeDataLoader: ChromiumBrowserDataLoader {
    static let browserType: BrowserType = .edge
    static let bookmarksRelativePath =
        "Library/Application Support/Microsoft Edge/Default/Bookmarks"
    static let historyRelativePath = "Library/Application Support/Microsoft Edge/Default/History"
    static let shouldCopyHistoryDatabase = true
}
