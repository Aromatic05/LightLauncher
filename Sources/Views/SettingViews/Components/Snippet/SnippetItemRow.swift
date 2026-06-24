import SwiftUI

struct SnippetItemRow: View {
    let snippet: SnippetItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            snippetInfo
            actionButtons
        }
        .padding(16)
        .settingsCard(opacity: 1.0)
    }

    private var snippetInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snippet.name)
                    .font(.headline)
                    .fontWeight(.medium)

                if !snippet.keyword.isEmpty {
                    Badge(text: snippet.keyword, color: .blue)
                }

                Spacer()
            }

            Text(snippet.snippet)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button("编辑", action: onEdit)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("删除", action: onDelete)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
        }
    }
}
