import Foundation

class ChromeDataLoader: ChromiumBrowserDataLoader {
    static let browserType: BrowserType = .chrome
    static let bookmarksRelativePath = "Library/Application Support/Google/Chrome/Default/Bookmarks"
    static let historyRelativePath = "Library/Application Support/Google/Chrome/Default/History"
}
