import SwiftUI

struct SnippetComponents {

    struct EmptyStateView: View {
        let searchText: String
        let onAddSnippet: () -> Void

        var body: some View {
            EmptyStatePlaceholder(
                icon: searchText.isEmpty ? "doc.text" : "magnifyingglass",
                title: searchText.isEmpty ? "暂无代码片段" : "未找到匹配的片段",
                description: searchText.isEmpty
                    ? "点击上方按钮添加您的第一个代码片段"
                    : "尝试其他搜索关键词或添加新片段",
                actionTitle: searchText.isEmpty ? "添加片段" : nil,
                action: searchText.isEmpty ? onAddSnippet : nil
            )
        }
    }

    struct HeaderView: View {
        @Binding var searchText: String
        let hasSnippets: Bool
        let onClearAll: () -> Void

        var body: some View {
            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("筛选与维护")
                            .font(.headline)
                        Text("统一搜索、筛选和清理当前片段")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索片段...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                if hasSnippets {
                    Button("清空全部", action: onClearAll)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                }
            }
        }
    }
}
