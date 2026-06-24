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
        let onAddSnippet: () -> Void
        let onClearAll: () -> Void

        var body: some View {
            VStack(spacing: 16) {
                titleSection
                searchSection
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }

        private var titleSection: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("代码片段管理")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("管理您的代码片段和文本模板")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                AddButton(title: "添加片段", systemImage: "plus", action: onAddSnippet)
            }
        }

        private var searchSection: some View {
            HStack {
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
