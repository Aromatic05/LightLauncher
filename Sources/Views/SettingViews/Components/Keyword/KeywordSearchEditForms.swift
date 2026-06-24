import SwiftUI

struct KeywordSearchBasicForm: View {
    @Binding var title: String
    @Binding var keyword: String
    @Binding var icon: String
    @State private var isFileImporterPresented = false
    @State private var selectedIconName: String = ""
    private let fileAccess = FileAccessService.shared

    var body: some View {
        SettingsCard(title: "基本信息", contentSpacing: 12) {
            LabeledTextField(
                label: "搜索引擎名称",
                placeholder: "例如：Google",
                text: $title
            )
            LabeledTextField(
                label: "关键词",
                placeholder: "例如：g",
                text: $keyword,
                textCase: .lowercase
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("图标文件 (可选)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    Button("选择图标文件") {
                        isFileImporterPresented = true
                    }
                    .buttonStyle(.bordered)
                    if !selectedIconName.isEmpty {
                        Text(selectedIconName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let iconsDir = fileAccess.homeDirectory.appendingPathComponent(
                        ".config/LightLauncher/icons", isDirectory: true)
                    do {
                        try fileAccess.ensureDirectory(iconsDir)
                        let destURL = iconsDir.appendingPathComponent(url.lastPathComponent)
                        try fileAccess.removeItemIfExists(at: destURL)
                        try fileAccess.copyItem(at: url, to: destURL)
                        icon = url.lastPathComponent
                        selectedIconName = url.lastPathComponent
                    } catch {
                        selectedIconName = "文件保存失败"
                    }
                }
            case .failure(_):
                selectedIconName = "未选择文件"
            }
        }
    }
}

struct KeywordSearchConfigForm: View {
    @Binding var url: String
    @Binding var spaceEncoding: String

    var body: some View {
        SettingsCard(title: "搜索配置", contentSpacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                LabeledTextField(
                    label: "搜索 URL",
                    placeholder: "https://www.google.com/search?q={query}",
                    text: $url
                )
                Text("使用 {query} 作为查询占位符")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("空格编码")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("空格编码", selection: $spaceEncoding) {
                    Text("+").tag("+")
                    Text("%20").tag("%20")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

struct KeywordSearchPreview: View {
    let isValid: Bool
    let keyword: String
    let url: String

    var body: some View {
        SettingsCard(title: "预览", contentSpacing: 12) {
            if isValid {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("使用示例:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(keyword) Swift")
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("生成的 URL:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        let exampleURL = url.replacingOccurrences(of: "{query}", with: "Swift")
                        Text(exampleURL)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("请填写完整信息")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    if !url.contains("{query}") && !url.isEmpty {
                        Text("⚠️ URL 中必须包含 {query} 占位符")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
        }
    }
}
