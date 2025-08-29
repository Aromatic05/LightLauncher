import SwiftUI

// MARK: - 关键词搜索空状态视图
struct KeywordSearchEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("暂无搜索项")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("点击\"添加搜索项\"按钮创建您的第一个关键词搜索")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 关键词搜索说明卡片
struct KeywordSearchInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("关键词搜索")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("使用方法：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("• 输入关键词 + 空格 + 搜索内容，例如：g Swift")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 系统会自动在对应的搜索引擎中搜索")
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

// MARK: - 关键词搜索列表头部
struct KeywordSearchListHeader: View {
    let onAddAction: () -> Void

    var body: some View {
        HStack {
            Text("搜索项配置")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onAddAction) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("添加搜索项")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
