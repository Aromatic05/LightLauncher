import SwiftUI

// MARK: - 缩写匹配设置视图
struct AbbreviationSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var newAbbreviation = ""
    @State private var newMatchWords = ""
    @State private var editingKey: String?
    @State private var editingValues: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                titleSection
                abbreviationListSection
                Spacer()
            }
            .padding(32)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("缩写匹配")
                .font(.title)
                .fontWeight(.bold)
            Text("配置应用程序缩写匹配规则，提高搜索效率")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var abbreviationListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("当前缩写规则")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(configManager.config.commonAbbreviations.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(configManager.config.commonAbbreviations.keys.sorted()), id: \.self) { key in
                    AbbreviationRow(
                        key: key,
                        values: configManager.config.commonAbbreviations[key] ?? [],
                        isEditing: editingKey == key,
                        editingValues: $editingValues,
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
    
    private func addAbbreviation() {
        guard !newAbbreviation.isEmpty && !newMatchWords.isEmpty else { return }
        let words = newMatchWords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        configManager.addAbbreviation(key: newAbbreviation.lowercased(), values: words)
        newAbbreviation = ""
        newMatchWords = ""
    }
    
    private func cancelEdit() {
        editingKey = nil
        editingValues = ""
    }
    
    private func deleteAbbreviation(key: String) {
        configManager.removeAbbreviation(key: key)
    }
}
