import SwiftUI

struct SnippetEditForms {

    struct BasicInfoForm: View {
        @Binding var name: String
        @Binding var keyword: String

        var body: some View {
            SettingsCard(title: "基本信息", contentSpacing: 12) {
                LabeledTextField(
                    label: "片段名称",
                    placeholder: "例如：函数模板",
                    text: $name
                )
                VStack(alignment: .leading, spacing: 6) {
                    LabeledTextField(
                        label: "关键词",
                        placeholder: "例如：func",
                        text: $keyword
                    )
                    Text("用于快速搜索和匹配的关键词")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct ContentForm: View {
        @Binding var snippetText: String

        var body: some View {
            SettingsCard(title: "代码内容") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("片段内容")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextEditor(text: $snippetText)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if snippetText.isEmpty {
                                Text("输入您的代码片段或文本模板")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                    Text("支持多行文本和代码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct PreviewCard: View {
        let isValid: Bool
        let name: String
        let keyword: String
        let snippetText: String

        var body: some View {
            SettingsCard(title: "预览", contentSpacing: 12) {
                if isValid {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(name)
                                .font(.headline)
                                .fontWeight(.medium)
                            Badge(text: keyword, color: .blue)
                            Spacer()
                        }

                        Text(snippetText)
                            .font(.body)
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("请填写完整信息")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }
}
