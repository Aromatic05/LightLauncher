import SwiftUI
import Combine

// MARK: - 文件模式控制器
@MainActor
final class FileModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = FileModeController()
    private override init() {}

    // MARK: - ModeStateController 协议实现

    // 1. 身份与元数据
    let mode: LauncherMode = .file
    let prefix: String? = "/o"
    let displayName: String = "File Browser"
    let iconName: String = "folder"
    let placeholder: String = "Browse files or folders..."
    let modeDescription: String? = "Browse your file system"

    @Published var displayableItems: [any DisplayableItem] = [] {
        didSet {
            dataDidChange.send()
        }
    }
    let dataDidChange = PassthroughSubject<Void, Never>()

    var interceptedKeys: Set<KeyEvent> {
        return [.space]
    }

    func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .space:
            if !showStartPaths {
                openInFinder()
                return true
            }
            return false
        default:
            return false
        }
    }

    // 2. 核心逻辑
    func handleInput(arguments: String) {
        let currentQuery = "/o \(arguments)"
        
        if currentQuery.count < lastProcessedQuery.count {
            lastInputAction = .delete
        } else {
            lastInputAction = .input
        }

        if currentQuery == lastProcessedQuery {
            return
        }
        lastProcessedQuery = currentQuery

        if !isInitialized {
            isInitialized = true
        }

        let (newPath, searchQuery) = parseInputArguments(arguments)
        
        if let path = newPath {
            if path == "" {
                resetToStartScreen()
                return
            }
            
            // 正常导航
            updateCurrentPath(to: path, with: searchQuery)
        } else {
            // 在当前视图下筛选
            let items: [any DisplayableItem]
            if showStartPaths {
                items = getStartPathItems(query: searchQuery)
            } else {
                items = getFileItems(path: currentPath, query: searchQuery)
            }
            self.displayableItems = items
        }
        
        if displayableItems.isEmpty {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else { return false }

        if let startPath = self.displayableItems[index] as? FileBrowserStartPath {
            navigateToDirectory(URL(fileURLWithPath: startPath.path))
            return false
        }
        
        if let fileItem = self.displayableItems[index] as? FileItem {
            if fileItem.isDirectory {
                navigateToDirectory(fileItem.url)
                return false
            } else {
                let success = NSWorkspace.shared.open(fileItem.url)
                if success {
                    resetToStartScreen()
                }
                return success
            }
        }
        
        return false
    }

    // 3. 生命周期与UI
    func cleanup() {
        displayableItems = []
        showStartPaths = true
        currentPath = NSHomeDirectory()
        isInitialized = false
        lastProcessedQuery = ""
        lastInputAction = .input
    }

    func makeContentView() -> AnyView {
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyStateView(
                icon: "folder.fill",
                iconColor: .blue.opacity(0.8),
                title: "File Browser",
                description: modeDescription,
                helpTexts: getHelpText()
            ))
        }
    }

    func getHelpText() -> [String] {
        return [
            "Enter to select or open.",
            "Type a path ending with '/' to navigate (e.g., '~/Desktop/').",
            "Backspace at the end of a path to go up a directory.",
            "Spacebar in a directory to open it in Finder."
        ]
    }
    
    // MARK: - 内部状态与辅助方法

    private enum InputAction { case input, delete }
    private var lastInputAction: InputAction = .input
    
    private var isInitialized = false
    private var lastProcessedQuery = ""

    @Published private var showStartPaths: Bool = true
    @Published private var currentPath: String = NSHomeDirectory()

    func navigateToDirectory(_ url: URL) {
        let standardizedURL = url.standardized
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            showPathError(message: "Cannot access directory at '\(url.path)'")
            return
        }
        
        updateCurrentPath(to: standardizedURL.path, with: "")
    }
    
    private func updateCurrentPath(to newPath: String, with searchQuery: String) {
        self.showStartPaths = false
        self.currentPath = newPath
        
        updateQueryInLauncher(path: newPath, searchQuery: searchQuery)
        
        self.displayableItems = getFileItems(path: newPath, query: searchQuery)
        LauncherViewModel.shared.selectedIndex = 0
    }

    private func updateQueryInLauncher(path: String, searchQuery: String) {
        let displayPath = getDisplayPath(for: path, asPrefix: true)
        let newQuery = "/o \(displayPath)\(searchQuery)"

        if lastProcessedQuery != newQuery {
            lastProcessedQuery = newQuery
            LauncherViewModel.shared.updateQuery(newQuery: newQuery)
        }
    }

    func resetToStartScreen() {
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
        
        let newQuery = "/o "
        if lastProcessedQuery != newQuery {
            lastProcessedQuery = newQuery
            LauncherViewModel.shared.updateQuery(newQuery: newQuery)
        }
        
        self.displayableItems = getStartPathItems(query: "")
        LauncherViewModel.shared.selectedIndex = 0
    }

    private func getStartPathItems(query: String) -> [FileBrowserStartPath] {
        let allPaths = ConfigManager.shared.getFileBrowserStartPaths().map { path in
            FileBrowserStartPath(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
        }
        if query.isEmpty {
            return allPaths
        }
        return allPaths.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func getFileItems(path: String, query: String) -> [FileItem] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        return FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
    }

    func openInFinder() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
    
    // MARK: - 路径解析与导航辅助方法

    private func parseInputArguments(_ arguments: String) -> (newPath: String?, searchQuery: String) {
        let trimmedArgs = arguments.trimmingCharacters(in: .whitespaces)

        // 规则 1 (最高优先级): 检查是否为导航命令 (以 / 结尾)
        if trimmedArgs.hasSuffix("/") {
            let pathToResolve = String(trimmedArgs.dropLast())
            let resolvedPath = resolvePath(from: pathToResolve)
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return (resolvedPath, "")
            }
        }
        
        if showStartPaths {
            return (nil, trimmedArgs)
        }
        
        // 规则 2: 检查是否为 "返回上一级" 的删除操作
        if lastInputAction == .delete {
            let displayPath = getDisplayPath(for: currentPath, asPrefix: true)
            
            // `displayPath` 保证以'/'结尾，所以可以直接比较
            if trimmedArgs == String(displayPath.dropLast()) {
                let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().standardized.path
                return (parentPath, "") // 让调用者决定如何处理 parentPath (即使 parentPath == currentPath)
            }
        }
        
        // 规则 3 (默认行为): 在当前目录内筛选
        let prefix = getDisplayPath(for: currentPath, asPrefix: true)
        let searchQuery = trimmedArgs.hasPrefix(prefix) ? String(trimmedArgs.dropFirst(prefix.count)) : trimmedArgs
        
        return (nil, searchQuery)
    }

    private func resolvePath(from input: String) -> String {
        if input.isEmpty {
            return "/"
        }
        
        let expandedInput = NSString(string: input).expandingTildeInPath
        return URL(fileURLWithPath: expandedInput).standardized.path
    }

    private func getDisplayPath(for path: String, asPrefix: Bool = false) -> String {
        let home = NSHomeDirectory()
        var displayPath: String
        
        if path == home {
            displayPath = "~"
        } else if path.hasPrefix(home + "/") {
            displayPath = "~" + String(path.dropFirst(home.count))
        } else {
            displayPath = path
        }
        
        if asPrefix && !displayPath.hasSuffix("/") {
            return displayPath + "/"
        }
        
        return displayPath
    }
    
    private func showPathError(message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Path Access Error"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}