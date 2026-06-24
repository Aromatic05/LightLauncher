import SwiftUI

struct ClipItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            switch item.payload {
            case .text:
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.accentColor)
                Text(item.textValue ?? "")
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .file:
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(item.fileURL?.lastPathComponent ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}
