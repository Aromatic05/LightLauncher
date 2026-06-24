import SwiftUI

struct KeywordSearchEmptyView: View {
    var body: some View {
        EmptyStatePlaceholder(
            icon: "magnifyingglass.circle",
            title: "暂无搜索项",
            description: "点击\"添加搜索项\"按钮创建您的第一个关键词搜索"
        )
    }
}

struct KeywordSearchInfoCard: View {
    var body: some View {
        SettingsCard {
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
    }
}

struct KeywordSearchListHeader: View {
    let onAddAction: () -> Void

    var body: some View {
        HStack {
            Text("搜索项配置")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            AddButton(title: "添加搜索项", systemImage: "plus", action: onAddAction)
        }
    }
}
