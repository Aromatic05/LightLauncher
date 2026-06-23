import Foundation

// MARK: - 浏览器数据加载协议
protocol BrowserDataLoader {
    static func loadBookmarks() async -> [BrowserItem]
    static func loadHistory() async -> [BrowserItem]
    static var browserType: BrowserType { get }
}

// MARK: - 通用工具方法
class BrowserDataUtils {
    private static let fileAccess = FileAccessService.shared

    /// 去重浏览器数据项
    static func removeDuplicates(from items: [BrowserItem]) -> [BrowserItem] {
        var seen = Set<String>()
        var result: [BrowserItem] = []

        for item in items {
            let key = "\(item.url)|\(item.type)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }

        return result
    }

    /// 检查文件是否存在
    static func fileExists(at path: String) -> Bool {
        return fileAccess.fileExists(atPath: path)
    }

    /// 获取用户主目录
    static var homeDirectory: URL {
        return fileAccess.homeDirectory
    }
}
