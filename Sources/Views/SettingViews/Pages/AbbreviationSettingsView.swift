import SwiftUI

// MARK: - 缩写匹配设置视图
// MARK: - 缩写匹配设置视图
struct AbbreviationSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var newAbbreviation = ""
    @State private var newMatchWords = ""
    @State private var editingKey: String?
    @State private var editingValues: String = ""

    var body: some View {
        StandardSettingsPage(title: "缩写匹配", subtitle: "配置应用程序缩写匹配规则，提高搜索效率") {
            StandardSettingsSection(title: "添加新缩写", icon: "plus.circle", iconColor: .blue) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("缩写")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("如: ps", text: $newAbbreviation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("匹配词 (用逗号分隔)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("如: photoshop, adobe photoshop", text: $newMatchWords)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        Button("添加") {
                            addAbbreviation()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newAbbreviation.isEmpty || newMatchWords.isEmpty)
                        .padding(.top, 16)
                    }
                }
                .padding(16)
                .settingsCard(opacity: 0.5)
            }

            StandardSettingsSection(
                    title: "当前缩写规则",
                    icon: "textformat.abc",
                    iconColor: .accentColor,
                    count: configManager.config.commonAbbreviations.count,
                    countLabel: "项"
            ) {
                LazyVStack(spacing: 8) {
                    ForEach(
                        Array(configManager.config.commonAbbreviations.keys.sorted()),
                        id: \.self
                    ) { key in
                        AbbreviationRow(
                            key: key,
                            values: configManager.config.commonAbbreviations[key] ?? [],
                            isEditing: editingKey == key,
                            editingValues: $editingValues,
                            onEdit: {
                                startEditing(key: key)
                            },
                            onSave: {
                                saveEdit(key: key)
                            },
                            onCancel: {
                                cancelEdit()
                            },
                            onDelete: {
                                deleteAbbreviation(key: key)
                            }
                        )
                    }
                }
            }
        }
    }

    private func addAbbreviation() {
        guard !newAbbreviation.isEmpty && !newMatchWords.isEmpty else { return }
        let words = newMatchWords.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        configManager.addAbbreviation(key: newAbbreviation.lowercased(), values: words)
        newAbbreviation = ""
        newMatchWords = ""
    }

    private func startEditing(key: String) {
        editingKey = key
        editingValues = (configManager.config.commonAbbreviations[key] ?? []).joined(
            separator: ", ")
    }

    private func saveEdit(key: String) {
        let words = editingValues.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        configManager.addAbbreviation(key: key, values: words)
        cancelEdit()
    }

    private func cancelEdit() {
        editingKey = nil
        editingValues = ""
    }

    private func deleteAbbreviation(key: String) {
        configManager.removeAbbreviation(key: key)
    }
}
