import SwiftUI

// MARK: - 关键词搜索项行视图
struct KeywordSearchItemRow: View {
    let item: KeywordSearchItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            iconView
            contentView
            actionButtons
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var iconView: some View {
        Group {
            if let icon = item.icon, !icon.isEmpty {
                AsyncImage(url: URL(string: icon)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                }
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                Text("关键词: \(item.keyword)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }

            Text(item.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
