import SwiftUI

// MARK: - 插件项目行视图
struct PluginItemRowView: View {
    let item: PluginItem
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            if let iconName = item.icon {
                if iconName.hasPrefix("data:") || iconName.contains("base64") {
                    // Base64 图片
                    AsyncImage(url: URL(string: iconName)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "app")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 32, height: 32)
                } else {
                    // SF Symbol
                    Image(systemName: iconName)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.primary)
                }
            } else {
                // 默认图标
                Image(systemName: "puzzlepiece")
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 索引数字
                    if index < 6 {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(Color.secondary.opacity(0.2))
                            )
                    }
                }
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}
