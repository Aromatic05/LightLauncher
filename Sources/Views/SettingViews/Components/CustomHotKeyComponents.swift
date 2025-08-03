import SwiftUI

// MARK: - 自定义快捷键空状态视图
struct CustomHotKeyEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "command.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("暂无自定义快捷键")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击\"添加快捷键\"按钮创建您的第一个自定义快捷键")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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

// MARK: - 自定义快捷键列表头部
struct CustomHotKeyListHeader: View {
    let onAddAction: () -> Void
    
    var body: some View {
        HStack {
            Text("快捷键配置")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onAddAction) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("添加快捷键")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
