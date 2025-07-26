import SwiftUI

struct SnippetItemRowView: View {
    let item: SnippetItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "text.append")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !item.keyword.isEmpty {
                    Text(item.keyword)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}
