import AppKit
import SwiftUI

/// 剪贴板历史记录项
struct ClipboardItem: Codable, Hashable, DisplayableItem {
    enum Payload: Codable, Hashable {
        case text, file
    }

    let id: UUID
    let payload: Payload
    let textValue: String?
    let fileURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, type, value
    }

    private enum ItemType: String, Codable {
        case text
        case file
    }

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.payload = .text
        self.textValue = text
        self.fileURL = nil
    }

    init(id: UUID = UUID(), fileURL: URL) {
        self.id = id
        self.payload = .file
        self.textValue = nil
        self.fileURL = fileURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .text:
            self.payload = .text
            self.textValue = try container.decode(String.self, forKey: .value)
            self.fileURL = nil
        case .file:
            self.payload = .file
            self.textValue = nil
            self.fileURL = try container.decode(URL.self, forKey: .value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch payload {
        case .text:
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(textValue, forKey: .value)
        case .file:
            try container.encode(ItemType.file, forKey: .type)
            try container.encode(fileURL, forKey: .value)
        }
    }

    var directInputText: String? {
        switch payload {
        case .text:
            return textValue
        case .file:
            return fileURL?.path
        }
    }

    func hasSamePayload(as other: ClipboardItem) -> Bool {
        payload == other.payload
            && textValue == other.textValue
            && fileURL == other.fileURL
    }

    var title: String {
        switch payload {
        case .text:
            return textValue ?? ""
        case .file:
            return fileURL?.lastPathComponent ?? ""
        }
    }

    var subtitle: String? {
        switch payload {
        case .text:
            return nil
        case .file:
            return fileURL?.path
        }
    }

    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(ClipItemRowView(item: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        if let historyIndex = ClipboardManager.shared.getHistory().firstIndex(where: { $0.id == id }) {
            ClipboardManager.shared.removeItem(at: historyIndex)
        }

        switch payload {
        case .text:
            if let textValue {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textValue, forType: .string)
            }
        case .file:
            if let fileURL {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([fileURL as NSURL])
            }
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
    @ViewBuilder
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        AnyView(SnippetItemRowView(item: self, isSelected: isSelected, index: index))
    }

    @MainActor
    func executeAction() -> Bool {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self.snippet, forType: .string)
        return true
    }
}
