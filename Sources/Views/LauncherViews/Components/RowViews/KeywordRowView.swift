import AppKit
import SwiftUI

struct KeywordRowView: View {
    let keyword: String
    let title: String
    let icon: NSImage?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            if let nsImage = icon {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(".")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(keyword)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text(":")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                Text("按回车执行自定义搜索")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "return")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.blue.opacity(0.05))
        )
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 1)
                }
            }
        )
    }
}
