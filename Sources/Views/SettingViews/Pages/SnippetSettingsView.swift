import SwiftUI

// MARK: - 代码片段设置页面
struct SnippetSettingsView: View {
    @StateObject private var snippetManager = SnippetManager.shared
    @State private var showingAddSnippet = false
    @State private var editingSnippet: SnippetItem?
    @State private var searchText = ""

    private var displayedSnippets: [SnippetItem] {
        if searchText.isEmpty {
            return snippetManager.snippets
        }
        return snippetManager.searchSnippets(query: searchText)
    }

    var body: some View {
        StandardSettingsPage(title: "代码片段", subtitle: "统一管理您的文本模板和代码片段") {
            StandardSettingsSection(title: "片段管理", icon: "slider.horizontal.3", iconColor: .blue) {
                SettingsCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("片段操作")
                                .font(.headline)
                            Text("新增片段并维护当前片段集合")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        AddButton(title: "添加片段", systemImage: "plus") {
                            showingAddSnippet = true
                        }
                    }
                }

                SnippetComponents.HeaderView(
                    searchText: $searchText,
                    hasSnippets: !snippetManager.snippets.isEmpty,
                    onClearAll: { snippetManager.clearSnippets() }
                )
            }

            StandardSettingsSection(
                title: "当前片段",
                icon: "doc.text",
                iconColor: .blue,
                count: displayedSnippets.count,
                countLabel: "项"
            ) {
                contentView
            }
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
            if displayedSnippets.isEmpty {
                SnippetComponents.EmptyStateView(
                    searchText: searchText,
                    onAddSnippet: { showingAddSnippet = true }
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(displayedSnippets, id: \.id) { snippet in
                        SnippetItemRow(
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
            }
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
            EditSheetHeader(
                title: snippet == nil ? "添加代码片段" : "编辑代码片段",
                isValid: isValid,
                onSave: { saveSnippet() }
            )
            Divider()

            Form {
                SnippetEditForms.BasicInfoForm(name: $name, keyword: $keyword)
                SnippetEditForms.ContentForm(snippetText: $snippetText)
                SnippetEditForms.PreviewCard(
                    isValid: isValid,
                    name: name,
                    keyword: keyword,
                    snippetText: snippetText
                )
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
