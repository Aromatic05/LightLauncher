import SwiftUI

// MARK: - 片段编辑表单组件
struct SnippetEditForms {

    // MARK: - 基本信息表单
    struct BasicInfoForm: View {
        @Binding var name: String
        @Binding var keyword: String

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("基本信息")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("片段名称")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("例如：函数模板", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("关键词")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("例如：func", text: $keyword)
                            .textFieldStyle(.roundedBorder)
                        Text("用于快速搜索和匹配的关键词")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    // MARK: - 内容编辑表单
    struct ContentForm: View {
        @Binding var snippetText: String

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("代码内容")
                    .font(.headline)
                    .fontWeight(.semibold)

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
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    // MARK: - 预览卡片
    struct PreviewCard: View {
        let isValid: Bool
        let name: String
        let keyword: String
        let snippetText: String

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("预览")
                    .font(.headline)
                    .fontWeight(.semibold)

                if isValid {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(name)
                                .font(.headline)
                                .fontWeight(.medium)

                            Text(keyword)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
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
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}
