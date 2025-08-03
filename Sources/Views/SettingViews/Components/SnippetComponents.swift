import SwiftUI

// MARK: - 片段页面组件
struct SnippetComponents {
    
    // MARK: - 空状态视图
    struct EmptyStateView: View {
        let searchText: String
        let onAddSnippet: () -> Void
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "暂无代码片段" : "未找到匹配的片段")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? 
                         "点击上方按钮添加您的第一个代码片段" : 
                         "尝试其他搜索关键词或添加新片段")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button("添加片段") {
                        onAddSnippet()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
    }
    
    // MARK: - 头部视图
    struct HeaderView: View {
        @Binding var searchText: String
        let hasSnippets: Bool
        let onAddSnippet: () -> Void
        let onClearAll: () -> Void
        
        var body: some View {
            VStack(spacing: 16) {
                titleSection
                searchSection
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        
        private var titleSection: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("代码片段管理")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("管理您的代码片段和文本模板")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("添加片段") {
                    onAddSnippet()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
        private var searchSection: some View {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索片段...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                if hasSnippets {
                    Button("清空全部") {
                        onClearAll()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
    }
}
