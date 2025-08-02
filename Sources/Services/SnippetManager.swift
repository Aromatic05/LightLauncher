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

    private init(maxSnippetsCount: Int = 200) {
        self.maxSnippetsCount = maxSnippetsCount
        let docDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/LightLauncher", isDirectory: true)
        self.snippetsDirectory = docDir
        self.snippetsFileURL = docDir.appendingPathComponent("snippets.json")
        loadSnippets()
    }

    /// 获取全部 Snippet
    func getSnippets() -> [SnippetItem] {
        return snippets
    }

    /// 查找 Snippet，支持 name、keyword、snippet 模糊匹配
    func searchSnippets(query: String) -> [SnippetItem] {
        let q = query.lowercased()
        return snippets.filter {
            $0.name.lowercased().contains(q) ||
            $0.keyword.lowercased().contains(q) ||
            $0.snippet.lowercased().contains(q)
        }
    }

    /// 添加 Snippet
    func addSnippet(_ item: SnippetItem) {
        if !snippets.contains(item) {
            snippets.insert(item, at: 0)
            if snippets.count > maxSnippetsCount {
                snippets = Array(snippets.prefix(maxSnippetsCount))
            }
            saveSnippets()
        }
    }

    /// 删除指定下标的 Snippet
    func removeSnippet(at index: Int) {
        guard snippets.indices.contains(index) else { return }
        snippets.remove(at: index)
        saveSnippets()
    }

    /// 清空所有 Snippet
    func clearSnippets() {
        snippets.removeAll()
        saveSnippets()
    }

    /// 加载 Snippet
    private func loadSnippets() {
        do {
            try FileManager.default.createDirectory(at: snippetsDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: snippetsFileURL.path) {
                let data = try Data(contentsOf: snippetsFileURL)
                let decoded = try JSONDecoder().decode([SnippetItem].self, from: data)
                self.snippets = Array(decoded.prefix(maxSnippetsCount))
            }
        } catch {
            print("Snippet 加载失败: \(error)")
        }
    }

    /// 保存 Snippet
    private func saveSnippets() {
        do {
            try FileManager.default.createDirectory(at: snippetsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(snippets.prefix(maxSnippetsCount)))
            try data.write(to: snippetsFileURL)
        } catch {
            print("Snippet 保存失败: \(error)")
        }
    }
}
