
import SwiftUI

/// 通用空状态视图，可自定义图标、标题、描述和帮助文本
struct EmptyStateView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    let helpTexts: [String]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            if let description = description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            if !helpTexts.isEmpty {
                VStack(spacing: 4) {
                    ForEach(helpTexts, id: \ .self) { helpText in
                        Text(helpText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }
}