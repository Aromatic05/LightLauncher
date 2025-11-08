import AppKit
import SwiftUI

// MARK: - 文件浏览器路径设置视图
struct FileBrowserPathSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var startPaths: [String] = []
    @State private var showingFilePicker = false
    @State private var newPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("File Browser Start Paths")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Configure directories that appear when entering file browser mode (/o)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 路径列表
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(startPaths.enumerated()), id: \.offset) { index, path in
                        StartPathRow(
                            path: path,
                            onRemove: {
                                removePath(at: index)
                            }
                        )
                    }

                    if startPaths.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("No start paths configured")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxHeight: 200)

            // 添加路径控件
            VStack(alignment: .leading, spacing: 8) {
                Text("Add New Path:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("Enter directory path or browse...", text: $newPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Browse") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button("Add") {
                        addPath()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(newPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // 预设路径按钮
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    QuickAddButton("Home", path: NSHomeDirectory())
                    QuickAddButton("Desktop", path: NSHomeDirectory() + "/Desktop")
                    QuickAddButton("Downloads", path: NSHomeDirectory() + "/Downloads")
                    QuickAddButton("Documents", path: NSHomeDirectory() + "/Documents")
                }

                HStack {
                    QuickAddButton("Applications", path: "/Applications")
                    QuickAddButton("Developer", path: NSHomeDirectory() + "/Developer")

                    Spacer()
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            loadStartPaths()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    newPath = url.path
                }
            case .failure(let error):
                    Logger.shared.error("File picker error: \(error)")
                    // Handle the error appropriately
                    // You might want to show an alert or some UI feedback here
            }
        }
    }

    @ViewBuilder
    private func QuickAddButton(_ title: String, path: String) -> some View {
        Button(title) {
            if !startPaths.contains(path) {
                newPath = path
                addPath()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(startPaths.contains(path))
    }

    private func loadStartPaths() {
        startPaths = configManager.getFileBrowserStartPaths()
    }

    private func addPath() {
        let trimmedPath = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }

        // 检查路径是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmedPath, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            // 可以在这里显示错误提示
            return
        }

        // 避免重复添加
        guard !startPaths.contains(trimmedPath) else {
            newPath = ""
            return
        }

        startPaths.append(trimmedPath)
        configManager.updateFileBrowserStartPaths(startPaths)
        newPath = ""
    }

    private func removePath(at index: Int) {
        guard index >= 0 && index < startPaths.count else { return }
        startPaths.remove(at: index)
        configManager.updateFileBrowserStartPaths(startPaths)
    }
}

// MARK: - 起始路径行视图
struct StartPathRow: View {
    let path: String
    let onRemove: () -> Void

    var body: some View {
        HStack {
            // 文件夹图标
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))

            // 路径信息
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 14, weight: .medium))

                Text(displayPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态指示器
            if pathExists {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
            }

            // 删除按钮
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Remove this path")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }

    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var displayPath: String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    private var pathExists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
