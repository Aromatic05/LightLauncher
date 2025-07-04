import Foundation
import SQLite3

// MARK: - 浏览器数据加载协议
protocol BrowserDataLoader {
    static func loadBookmarks() async -> [BrowserItem]
    static func loadHistory() async -> [BrowserItem]
    static var browserType: BrowserType { get }
}

// MARK: - 通用工具方法
class BrowserDataUtils {
    
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
    
    /// 安全地从 SQLite 读取字符串
    static func safeString(from statement: OpaquePointer?, at index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: cString)
    }
    
    /// 检查文件是否存在
    static func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// 获取用户主目录
    static var homeDirectory: URL {
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
