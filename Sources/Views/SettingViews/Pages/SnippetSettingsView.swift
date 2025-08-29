import SwiftUI

// MARK: - 代码片段设置页面
struct SnippetSettingsView: View {
    @StateObject private var snippetManager = SnippetManager.shared
    @State private var showingAddSnippet = false
    @State private var editingSnippet: SnippetItem?
    @State private var searchText = ""
    @State private var filteredSnippets: [SnippetItem] = []
    @State private var searchDebounceTimer: Timer?

    private func updateFilteredSnippets() {
        // 去抖动：避免在用户输入时频繁搜索
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                doUpdateFilteredSnippets()
            }
        }
    }

    private func doUpdateFilteredSnippets() {
        if searchText.isEmpty {
            filteredSnippets = snippetManager.snippets
        } else {
            filteredSnippets = snippetManager.searchSnippets(query: searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SnippetComponents.HeaderView(
                searchText: $searchText,
                hasSnippets: !snippetManager.snippets.isEmpty,
                onAddSnippet: { showingAddSnippet = true },
                onClearAll: { snippetManager.clearSnippets() }
            )
            Divider()
            contentView
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            doUpdateFilteredSnippets()  // 直接更新，不需要延迟
        }
        .onChange(of: searchText) { _ in
            updateFilteredSnippets()  // 使用去抖动
        }
        .onChange(of: snippetManager.snippets) { _ in
            doUpdateFilteredSnippets()  // 数据变化时立即更新
        }
        .sheet(isPresented: $showingAddSnippet) {
            SnippetEditView(snippet: nil) { newSnippet in
                snippetManager.addSnippet(newSnippet)
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditView(snippet: snippet) { updatedSnippet in
                snippetManager.updateSnippet(snippet, with: updatedSnippet)
            }
        }
    }

    private var contentView: some View {
        Group {
            if filteredSnippets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text(searchText.isEmpty ? "暂无代码片段" : "未找到匹配的片段")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(searchText.isEmpty ? "点击上方按钮添加您的第一个代码片段" : "尝试其他搜索关键词或添加新片段")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if searchText.isEmpty {
                        Button("添加片段") {
                            showingAddSnippet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSnippets, id: \.id) { snippet in
                            SnippetRow(
                                snippet: snippet,
                                onEdit: { editingSnippet = snippet },
                                onDelete: {
                                    if let index = snippetManager.snippets.firstIndex(of: snippet) {
                                        snippetManager.removeSnippet(at: index)
                                    }
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - 简化的片段行视图
private struct SnippetRow: View {
    let snippet: SnippetItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            snippetInfo
            actionButtons
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var snippetInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snippet.name)
                    .font(.headline)
                    .fontWeight(.medium)

                if !snippet.keyword.isEmpty {
                    Text(snippet.keyword)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()
            }

            Text(snippet.snippet)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button("编辑") { onEdit() }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("删除") { onDelete() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
        }
    }
}

// MARK: - 片段编辑视图
struct SnippetEditView: View {
    let snippet: SnippetItem?
    let onSave: (SnippetItem) -> Void

    @State private var name: String
    @State private var keyword: String
    @State private var snippetText: String

    @Environment(\.dismiss) private var dismiss

    init(snippet: SnippetItem?, onSave: @escaping (SnippetItem) -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        self._name = State(initialValue: snippet?.name ?? "")
        self._keyword = State(initialValue: snippet?.keyword ?? "")
        self._snippetText = State(initialValue: snippet?.snippet ?? "")
    }

    private var isValid: Bool {
        !name.isEmpty && !keyword.isEmpty && !snippetText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(snippet == nil ? "添加代码片段" : "编辑代码片段")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)

                Button("保存") { saveSnippet() }
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider()

            // 表单内容
            Form {
                Section("基本信息") {
                    TextField("片段名称", text: $name)
                    TextField("关键词", text: $keyword)
                }

                Section("内容") {
                    VStack(alignment: .leading) {
                        Text("片段内容")
                            .font(.headline)
                        TextEditor(text: $snippetText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150)
                    }
                }

                if isValid {
                    Section("预览") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(name).fontWeight(.medium)
                                Text(keyword)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                Spacer()
                            }
                            Text(snippetText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }

    private func saveSnippet() {
        let newSnippet = SnippetItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            snippet: snippetText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(newSnippet)
        dismiss()
    }
}
