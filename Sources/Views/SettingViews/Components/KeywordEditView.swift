import SwiftUI

// MARK: - 关键词搜索项编辑视图
struct KeywordSearchItemEditView: View {
    let item: KeywordSearchItem?
    let onSave: (KeywordSearchItem) -> Void
    
    @State private var title: String
    @State private var keyword: String
    @State private var url: String
    @State private var icon: String
    @State private var spaceEncoding: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(item: KeywordSearchItem?, onSave: @escaping (KeywordSearchItem) -> Void) {
        self.item = item
        self.onSave = onSave
        self._title = State(initialValue: item?.title ?? "")
        self._keyword = State(initialValue: item?.keyword ?? "")
        self._url = State(initialValue: item?.url ?? "")
        self._icon = State(initialValue: item?.icon ?? "")
        self._spaceEncoding = State(initialValue: item?.spaceEncoding ?? "+")
    }
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        url.contains("{query}")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Text(item == nil ? "添加搜索项" : "编辑搜索项")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("保存") {
                saveItem()
            }
            .disabled(!isValid)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                KeywordSearchBasicForm(
                    title: $title,
                    keyword: $keyword,
                    icon: $icon
                )
                
                KeywordSearchConfigForm(
                    url: $url,
                    spaceEncoding: $spaceEncoding
                )
                
                KeywordSearchPreview(
                    isValid: isValid,
                    keyword: keyword,
                    url: url
                )
            }
            .padding(20)
        }
    }
    
    private func saveItem() {
        let newItem = KeywordSearchItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            icon: icon.isEmpty ? nil : icon,
            spaceEncoding: spaceEncoding
        )
        onSave(newItem)
        dismiss()
    }
}