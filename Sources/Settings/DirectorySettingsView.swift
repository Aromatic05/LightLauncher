import SwiftUI

// MARK: - 搜索目录设置视图
struct DirectorySettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var newDirectory = ""
    @State private var showingDirectoryPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索目录")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("配置应用程序搜索目录，支持 ~ 符号表示用户主目录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 添加新目录
                VStack(alignment: .leading, spacing: 16) {
                    Text("添加搜索目录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        TextField("输入目录路径 (如: ~/Applications)", text: $newDirectory)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("浏览") {
                            showingDirectoryPicker = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("添加") {
                            addDirectory()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newDirectory.isEmpty)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                }
                
                // 目录列表
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("当前搜索目录")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(configManager.config.searchDirectories.count) 个目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(configManager.config.searchDirectories.enumerated()), id: \.offset) { index, directory in
                            SettingsDirectoryRow(directory: directory) {
                                removeDirectory(at: index)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    newDirectory = url.path
                }
            case .failure(let error):
                print("选择目录失败: \(error)")
            }
        }
    }
    
    private func addDirectory() {
        guard !newDirectory.isEmpty else { return }
        configManager.addSearchDirectory(newDirectory)
        newDirectory = ""
    }
    
    private func removeDirectory(at index: Int) {
        let directory = configManager.config.searchDirectories[index]
        configManager.removeSearchDirectory(directory)
    }
}
