import SwiftUI
import AppKit

// MARK: - 文件模式结果视图
struct FileModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 当前路径显示
            CurrentPathView(currentPath: viewModel.currentPath)
            
            // 文件列表
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(viewModel.currentFiles.enumerated()), id: \.element) { index, file in
                            FileRowView(
                                file: file,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    // 文件模式下打开文件后关闭窗口，但进入目录不关闭
                                    if !file.isDirectory {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                            }
                            .focusable(false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focusable(false)
                }
                .focusable(false)
                .onChange(of: viewModel.selectedIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - 当前路径视图
struct CurrentPathView: View {
    let currentPath: String
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.system(size: 12))
            
            Text(displayPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var displayPath: String {
        let home = NSHomeDirectory()
        if currentPath.hasPrefix(home) {
            return "~" + String(currentPath.dropFirst(home.count))
        }
        return currentPath
    }
}

// MARK: - 文件行视图
struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            // 图标
            if let icon = file.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(file.isDirectory ? .blue : .gray)
                    .frame(width: 24, height: 24)
            }
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(file.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 文件大小
                    if !file.displaySize.isEmpty {
                        Text(file.displaySize)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
                
                // 修改时间
                if let modificationDate = file.modificationDate {
                    Text(DateFormatter.fileDate.string(from: modificationDate))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 文件命令输入视图（空状态）
struct FileCommandInputView: View {
    let currentPath: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("File Browser")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Current directory: \(displayPath)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Navigation:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("• Enter:")
                            .fontWeight(.medium)
                        Text("Open file or enter directory")
                    }
                    HStack {
                        Text("• Space:")
                            .fontWeight(.medium)
                        Text("Open current directory in Finder")
                    }
                    HStack {
                        Text("• Type:")
                            .fontWeight(.medium)
                        Text("Filter files and folders")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var displayPath: String {
        let home = NSHomeDirectory()
        if currentPath.hasPrefix(home) {
            return "~" + String(currentPath.dropFirst(home.count))
        }
        return currentPath
    }
}

// MARK: - 日期格式化扩展
extension DateFormatter {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
