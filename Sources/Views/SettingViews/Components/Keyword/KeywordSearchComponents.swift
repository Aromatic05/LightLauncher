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
