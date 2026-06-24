import Foundation

class ArcDataLoader: ChromiumBrowserDataLoader {
    static let browserType: BrowserType = .arc
    static let bookmarksRelativePath = "Library/Application Support/Arc/User Data/Default/Bookmarks"
    static let historyRelativePath = "Library/Application Support/Arc/User Data/Default/History"
}
