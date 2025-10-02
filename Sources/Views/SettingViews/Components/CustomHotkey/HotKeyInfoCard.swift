import SwiftUI

struct HotKeyInfoCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iconColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - 自定义快捷键说明卡片
struct CustomHotKeyInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.purple)
                Text("快捷键功能")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("功能说明：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("• 设置全局快捷键来快速输入预设文本")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 可用于邮箱地址、常用短语、代码片段等")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 在任何应用中都可以使用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 20)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
