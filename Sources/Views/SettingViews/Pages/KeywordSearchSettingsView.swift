import SwiftUI

// MARK: - 关键词搜索设置视图
struct KeywordSearchSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var showingAddSheet = false
    @State private var editingItem: KeywordSearchItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("关键词搜索")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("管理自定义搜索引擎和快速搜索关键词")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 说明卡片
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
                
                Divider()
                
                // 搜索项列表
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("搜索项配置")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("添加搜索项")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if configManager.config.modes.keywordModeConfig?.items.isEmpty ?? true {
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
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(configManager.config.modes.keywordModeConfig?.items ?? []) { item in
                                KeywordSearchItemRow(
                                    item: item,
                                    onEdit: {
                                        editingItem = item
                                    },
                                    onDelete: {
                                        removeKeywordSearchItem(item)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showingAddSheet) {
            KeywordSearchItemEditView(
                item: nil,
                onSave: { newItem in
                    addKeywordSearchItem(newItem)
                }
            )
        }
        .sheet(item: $editingItem) { item in
            KeywordSearchItemEditView(
                item: item,
                onSave: { updatedItem in
                    updateKeywordSearchItem(updatedItem)
                }
            )
        }
    }
    
    private func addKeywordSearchItem(_ item: KeywordSearchItem) {
        var config = configManager.config
        if config.modes.keywordModeConfig == nil {
            config.modes.keywordModeConfig = KeywordModeConfig(items: [])
        }
        config.modes.keywordModeConfig?.items.append(item)
        configManager.config = config
        configManager.saveConfig()
    }
    
    private func updateKeywordSearchItem(_ updatedItem: KeywordSearchItem) {
        var config = configManager.config
        if let index = config.modes.keywordModeConfig?.items.firstIndex(where: { $0.id == updatedItem.id }) {
            config.modes.keywordModeConfig?.items[index] = updatedItem
            configManager.config = config
            configManager.saveConfig()
        }
    }
    
    private func removeKeywordSearchItem(_ item: KeywordSearchItem) {
        var config = configManager.config
        config.modes.keywordModeConfig?.items.removeAll { $0.id == item.id }
        configManager.config = config
        configManager.saveConfig()
    }
}

// MARK: - 关键词搜索项行视图
struct KeywordSearchItemRow: View {
    let item: KeywordSearchItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Group {
                if let icon = item.icon, !icon.isEmpty {
                    AsyncImage(url: URL(string: icon)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text("关键词: \(item.keyword)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                Text(item.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

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
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("搜索引擎名称", text: $title)
                    TextField("关键词 (例如: g)", text: $keyword)
                        .textCase(.lowercase)
                    TextField("图标 URL (可选)", text: $icon)
                }
                
                Section(header: Text("搜索配置")) {
                    TextField("搜索 URL", text: $url)
                        .help("使用 {query} 作为查询占位符，例如: https://www.google.com/search?q={query}")
                    
                    Picker("空格编码", selection: $spaceEncoding) {
                        Text("+").tag("+")
                        Text("%20").tag("%20")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("预览")) {
                    if isValid {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("使用示例: \(keyword) Swift")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let exampleURL = url.replacingOccurrences(of: "{query}", with: "Swift")
                            Text("生成的 URL: \(exampleURL)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("请填写完整信息")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(item == nil ? "添加搜索项" : "编辑搜索项")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}
