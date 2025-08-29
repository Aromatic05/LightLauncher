import AppKit
import SwiftUI

/// 剪切板历史记录项
enum ClipboardItem: Codable, Equatable, DisplayableItem {
    case text(String)
    case file(URL)

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    enum ItemType: String, Codable {
        case text, file
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .file:
            let value = try container.decode(URL.self, forKey: .value)
            self = .file(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let url):
            try container.encode(ItemType.file, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }

    var id: UUID {
        switch self {
        case .text(let str):
            return UUID(uuidString: str.hash.description) ?? UUID()
        case .file(let url):
            return UUID(uuidString: url.path.hash.description) ?? UUID()
        }
    }
    var title: String {
        switch self {
        case .text(let str):
            return str
        case .file(let url):
            return url.lastPathComponent
        }
    }
    var subtitle: String? {
        switch self {
        case .text:
            return nil
        case .file(let url):
            return url.path
        }
    }
    var icon: NSImage? {
        switch self {
        case .text:
            return nil
        case .file:
            return nil
        }
    }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(ClipItemRowView(item: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        if let historyIndex = ClipboardManager.shared.getHistory().firstIndex(of: self) {
            ClipboardManager.shared.removeItem(at: historyIndex)
        }
        switch self {
        case .text(let str):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str, forType: .string)
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        return true
    }
}

/// 快捷片段项，兼容 DisplayableItem
struct SnippetItem: Codable, Equatable, DisplayableItem, Identifiable {
    let id: UUID
    var name: String
    var keyword: String
    var snippet: String

    init(name: String, keyword: String, snippet: String) {
        self.id = UUID()
        self.name = name
        self.keyword = keyword
        self.snippet = snippet
    }

    // 为了支持 Codable，需要自定义编码/解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.keyword = try container.decode(String.self, forKey: .keyword)
        self.snippet = try container.decode(String.self, forKey: .snippet)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, keyword, snippet
    }

    var title: String { name }
    var subtitle: String? { keyword.isEmpty ? nil : keyword }
    var icon: NSImage? { nil }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        // 可自定义 SnippetItemRowView，暂用 Text 占位
        AnyView(SnippetItemRowView(item: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self.snippet, forType: .string)
        return true
    }
}
