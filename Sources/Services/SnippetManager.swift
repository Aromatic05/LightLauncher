import Foundation
import AppKit
import SwiftUI

/// 快捷片段管理器
@MainActor
class SnippetManager: ObservableObject {
    static let shared = SnippetManager()

    @Published private(set) var snippets: [SnippetItem] = []
    private let maxSnippetsCount: Int
    private let snippetsDirectory: URL
    private let snippetsFileURL: URL
    
    // 性能优化：批量保存
    private var saveTimer: Timer?
    private var needsSave = false
    
    // 性能优化：搜索缓存
    private var searchCache: [String: [SnippetItem]] = [:]

    private init(maxSnippetsCount: Int = 200) {
        self.maxSnippetsCount = maxSnippetsCount
        let docDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/LightLauncher", isDirectory: true)
        self.snippetsDirectory = docDir
        self.snippetsFileURL = docDir.appendingPathComponent("snippets.json")
        loadSnippetsAsync()
    }

    /// 获取全部 Snippet
    func getSnippets() -> [SnippetItem] {
        return snippets
    }

    /// 查找 Snippet，支持 name、keyword、snippet 模糊匹配
    func searchSnippets(query: String) -> [SnippetItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空查询直接返回全部
        if q.isEmpty {
            return snippets
        }
        
        // 检查缓存
        if let cached = searchCache[q] {
            return cached
        }
        
        // 优化搜索：先精确匹配，再模糊匹配
        let exactMatches = snippets.filter { snippet in
            snippet.keyword.lowercased() == q || snippet.name.lowercased() == q
        }
        
        if !exactMatches.isEmpty {
            searchCache[q] = exactMatches
            return exactMatches
        }
        
        // 模糊匹配
        let fuzzyMatches = snippets.filter { snippet in
            snippet.name.lowercased().contains(q) ||
            snippet.keyword.lowercased().contains(q) ||
            snippet.snippet.lowercased().contains(q)
        }
        
        // 缓存结果（限制缓存大小）
        if searchCache.count > 50 {
            searchCache.removeAll()
        }
        searchCache[q] = fuzzyMatches
        
        return fuzzyMatches
    }

    /// 更新 Snippet
    func updateSnippet(_ oldSnippet: SnippetItem, with newSnippet: SnippetItem) {
        if let index = snippets.firstIndex(of: oldSnippet) {
            snippets[index] = newSnippet
            searchCache.removeAll() // 清空搜索缓存
            scheduleSave()
        }
    }

    /// 添加 Snippet
    func addSnippet(_ item: SnippetItem) {
        if !snippets.contains(item) {
            snippets.insert(item, at: 0)
            if snippets.count > maxSnippetsCount {
                snippets = Array(snippets.prefix(maxSnippetsCount))
            }
            searchCache.removeAll() // 清空搜索缓存
            scheduleSave()
        }
    }

    /// 删除指定下标的 Snippet
    func removeSnippet(at index: Int) {
        guard snippets.indices.contains(index) else { return }
        snippets.remove(at: index)
        searchCache.removeAll() // 清空搜索缓存
        scheduleSave()
    }

    /// 清空所有 Snippet
    func clearSnippets() {
        snippets.removeAll()
        searchCache.removeAll() // 清空搜索缓存
        scheduleSave()
    }

    /// 异步加载 Snippet
    private func loadSnippetsAsync() {
        Task {
            await loadSnippets()
        }
    }
    
    /// 加载 Snippet
    private func loadSnippets() async {
        do {
            try FileManager.default.createDirectory(at: snippetsDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: snippetsFileURL.path) {
                let data = try Data(contentsOf: snippetsFileURL)
                let decoded = try JSONDecoder().decode([SnippetItem].self, from: data)
                await MainActor.run {
                    self.snippets = Array(decoded.prefix(maxSnippetsCount))
                }
            }
        } catch {
            print("Snippet 加载失败: \(error)")
        }
    }
    
    /// 延迟保存 - 避免频繁 I/O
    private func scheduleSave() {
        needsSave = true
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task {
                await self.performSave()
            }
        }
    }
    
    /// 执行保存
    private func performSave() async {
        guard needsSave else { return }
        needsSave = false
        
        do {
            try FileManager.default.createDirectory(at: snippetsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(snippets.prefix(maxSnippetsCount)))
            try data.write(to: snippetsFileURL)
        } catch {
            print("Snippet 保存失败: \(error)")
        }
    }
}
