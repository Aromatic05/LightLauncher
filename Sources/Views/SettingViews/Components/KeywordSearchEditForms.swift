import SwiftUI

// MARK: - 关键词搜索基本信息表单
struct KeywordSearchBasicForm: View {
    @Binding var title: String
    @Binding var keyword: String
    @Binding var icon: String
    @State private var isFileImporterPresented = false
    @State private var selectedIconName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("搜索引擎名称")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("例如：Google", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("关键词")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("例如：g", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.lowercase)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("图标文件 (可选)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Button(action: {
                            isFileImporterPresented = true
                        }) {
                            Text("选择图标文件")
                        }
                        if !selectedIconName.isEmpty {
                            Text(selectedIconName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                    let fileManager = FileManager.default
                    let homeDir = fileManager.homeDirectoryForCurrentUser
                    let iconsDir = homeDir.appendingPathComponent(".config/LightLauncher/icons", isDirectory: true)
                    do {
                        if !fileManager.fileExists(atPath: iconsDir.path) {
                            try fileManager.createDirectory(at: iconsDir, withIntermediateDirectories: true)
                        }
                        let destURL = iconsDir.appendingPathComponent(url.lastPathComponent)
                        // 覆盖同名文件
                        if fileManager.fileExists(atPath: destURL.path) {
                            try fileManager.removeItem(at: destURL)
                        }
                        try fileManager.copyItem(at: url, to: destURL)
                        icon = url.lastPathComponent
                        selectedIconName = url.lastPathComponent
                    } catch {
                        // 错误处理
                        selectedIconName = "文件保存失败"
                    }
                }
            case .failure(_):
                selectedIconName = "未选择文件"
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - 关键词搜索配置表单
struct KeywordSearchConfigForm: View {
    @Binding var url: String
    @Binding var spaceEncoding: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("搜索配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("搜索 URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("https://www.google.com/search?q={query}", text: $url)
                        .textFieldStyle(.roundedBorder)
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
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - 关键词搜索预览
struct KeywordSearchPreview: View {
    let isValid: Bool
    let keyword: String
    let url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("预览")
                .font(.headline)
                .fontWeight(.semibold)
            
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
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
