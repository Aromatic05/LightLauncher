import SwiftUI
import AppKit

// MARK: - 文件模式结果视图
struct FileModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showStartPaths {
                // 起始路径选择界面
                StartPathSelectionView(viewModel: viewModel)
            } else {
                // 文件浏览界面
                FileBrowserView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - 起始路径选择视图
struct StartPathSelectionView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                
                Text("Choose Starting Directory")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            
            // 路径列表
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                            if let startPath = item as? FileBrowserStartPath {
                                StartPathRowView(
                                    startPath: startPath,
                                    isSelected: index == viewModel.selectedIndex,
                                    index: index
                                )
                                .id(index)
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                    if viewModel.executeSelectedAction() {
                                        // 选择起始路径不关闭窗口
                                    }
                                }
                                .focusable(false)
                            }
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

// MARK: - 文件浏览视图
struct FileBrowserView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 当前路径显示
            CurrentPathView(currentPath: viewModel.currentPath)
            
            // 文件列表
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                            if let file = item as? FileItem {
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

// MARK: - 起始路径行视图
struct StartPathRowView: View {
    let startPath: FileBrowserStartPath
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
            if let icon = startPath.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            
            // 路径信息
            VStack(alignment: .leading, spacing: 4) {
                Text(startPath.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text(startPath.displayPath)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 箭头指示器
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
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
                
                Text("Choose a starting directory to begin browsing")
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
                        Text("Select directory or open file")
                    }
                    HStack {
                        Text("• Space:")
                            .fontWeight(.medium)
                        Text("Open in Finder")
                    }
                    HStack {
                        Text("• Type:")
                            .fontWeight(.medium)
                        Text("Filter directories")
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
