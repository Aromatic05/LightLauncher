import SwiftUI
import Combine

// MARK: - 文件模式控制器
@MainActor
final class FileModeController: NSObject, ModeStateController, ObservableObject {
    static let shared = FileModeController()
    private override init() {}

    // MARK: - ModeStateController Protocol Implementation
    
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
            openInFinder()
            return true // 空格键被消费
        default:
            return false
        }
    }
    
    // 2. 核心逻辑
    func handleInput(arguments: String) {
        // 检查是否是重复的查询，避免循环处理
        let currentQuery = "/o \(arguments)"
        if currentQuery == lastProcessedQuery {
            return
        }
        
        lastProcessedQuery = currentQuery
        
        // 标记为已初始化，允许属性观察器更新搜索框
        if !isInitialized {
            isInitialized = true
        }
        
        // 防抖机制：取消之前的定时器
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processInputWithDebounce(arguments: arguments)
            }
        }
    }
    
    private func processInputWithDebounce(arguments: String) {
        // 解析输入，提取路径和搜索查询
        let (pathFromInput, searchQuery) = parseInputArguments(arguments)
        
        // 如果输入包含路径信息，更新当前路径
        if let newPath = pathFromInput {
            updateCurrentPath(newPath)
        }
        
        // 根据当前状态获取项目
        if showStartPaths {
            let items = getStartPathItems(query: searchQuery)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            let items = getFileItems(path: currentPath, query: searchQuery)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        
        // 只在列表为空时才重置选中索引
        if displayableItems.isEmpty {
            LauncherViewModel.shared.selectedIndex = 0
        }
    }

    func executeAction(at index: Int) -> Bool {
        guard index >= 0 && index < self.displayableItems.count else { return false }
        
        if showStartPaths {
            guard let startPath = self.displayableItems[index] as? FileBrowserStartPath else { return false }
            navigateToDirectory(URL(fileURLWithPath: startPath.path))
            return false
        } else {
            guard let fileItem = self.displayableItems[index] as? FileItem else { return false }
            if fileItem.isDirectory {
                navigateToDirectory(fileItem.url)
                return false
            } else {
                let success = NSWorkspace.shared.open(fileItem.url)
                if success {
                    // After opening a file, reset to the initial screen
                    resetToStartScreen()
                }
                return success
            }
        }
    }

    // 3. 生命周期与UI
    func cleanup() {
        updateTimer?.invalidate()
        updateTimer = nil
        self.displayableItems = []
        // Crucially, reset the internal state to its default
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
        self.isInitialized = false
        self.lastProcessedQuery = ""
        // Clear the search box when exiting file mode
        LauncherViewModel.shared.updateQuery(newQuery: "")
    }
    
    func makeContentView() -> AnyView {
        // This view logic remains the same
        if !displayableItems.isEmpty {
            return AnyView(ResultsListView(viewModel: LauncherViewModel.shared))
        } else {
            return AnyView(EmptyStateView(
                icon: "folder.fill",
                iconColor: .blue.opacity(0.8),
                title: "文件浏览器",
                description: modeDescription,
                helpTexts: getHelpText()
            ))
        }
    }

    func getHelpText() -> [String] {
        return [
            "Enter to select a directory or open a file",
            "Space to open in Finder",
            "Type to filter the current list"
        ]
    }

    // MARK: - Internal State & Helper Methods
    
    private var isInitialized = false
    private var updateTimer: Timer?
    private var lastProcessedQuery = ""  // 记录最后处理的查询，防止循环
    
    @Published private var showStartPaths: Bool = true {
        didSet {
            // 当显示状态变化时，更新搜索框（但跳过初始化）
            if isInitialized {
                if showStartPaths {
                    let newQuery = "/o "
                    if lastProcessedQuery != newQuery {
                        lastProcessedQuery = newQuery
                        LauncherViewModel.shared.updateQuery(newQuery: newQuery)
                    }
                } else {
                    updateQuery(newQuery: currentPath)
                }
            }
        }
    }
    @Published private var currentPath: String = NSHomeDirectory() {
        didSet {
            // 当路径变化时，自动更新搜索框内容（但跳过初始化）
            if isInitialized && !showStartPaths {
                updateQuery(newQuery: currentPath)
            }
        }
    }
    
    func navigateToDirectory(_ url: URL) {
        let path = url.path
        
        // 验证路径是否有效
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            print("错误: 无法导航到无效路径: \(path)")
            showPathError(message: "无法访问目录 '\(url.lastPathComponent)'")
            return
        }
        
        self.showStartPaths = false
        self.currentPath = path
        // 直接加载目录内容
        let items = getFileItems(path: currentPath, query: "")
        self.displayableItems = items.map { $0 as any DisplayableItem }
        LauncherViewModel.shared.selectedIndex = 0
    }
    
    private func updateQuery(newQuery path: String) {
        let displayPath: String
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            displayPath = "~" + String(path.dropFirst(home.count))
        } else {
            displayPath = path
        }
        // 确保路径以 / 结尾，这样用户可以通过删除 / 来回到上一级目录
        let pathWithSlash = displayPath.hasSuffix("/") ? displayPath : displayPath + "/"
        let newQuery = "/o \(pathWithSlash)"
        
        // 只有当查询真的改变时才更新
        if lastProcessedQuery != newQuery {
            lastProcessedQuery = newQuery
            LauncherViewModel.shared.updateQuery(newQuery: newQuery)
        }
    }

    func resetToStartScreen() {
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
        // 直接加载起始路径，不更新搜索框
        let items = getStartPathItems(query: "")
        self.displayableItems = items.map { $0 as any DisplayableItem }
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
        // 在调用 FileManager 之前验证路径
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            print("警告: 尝试访问无效路径: \(path)")
            return []
        }
        
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        return FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
    }

    func openInFinder() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
    
    // MARK: - Path Parsing and Navigation Helper Methods
    
    /// 解析输入参数，分离路径和搜索查询
    private func parseInputArguments(_ arguments: String) -> (pathFromInput: String?, searchQuery: String) {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果输入为空，返回当前状态的搜索查询
        if trimmed.isEmpty {
            return (nil, "")
        }
        
        // 检查是否是删除末尾 / 回到上一级目录的操作
        if !showStartPaths {
            let currentDisplayPath = getCurrentDisplayPath()
            
            // 如果用户删除了末尾的 /，回到上一级目录
            if currentDisplayPath.hasSuffix("/") && trimmed == String(currentDisplayPath.dropLast()) {
                let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
                return (parentPath, "")
            }
            
            // 如果用户删除了路径的一部分，也回到上一级目录
            if trimmed.count < currentDisplayPath.count && currentDisplayPath.hasPrefix(trimmed) && trimmed.contains("/") {
                let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
                return (parentPath, "")
            }
        }
        
        // 特殊处理根目录的情况
        if trimmed == "/" {
            return ("/", "")
        }
        
        // 简化逻辑：只有当输入以/结尾时才尝试路径导航，否则作为搜索
        if (trimmed.hasPrefix("/") || trimmed.hasPrefix("~")) && trimmed.hasSuffix("/") && trimmed != "/" {
            let pathWithoutSlash = String(trimmed.dropLast())
            let expandedPath = expandPath(pathWithoutSlash)
            
            // 检查路径是否存在且为目录
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                return (expandedPath, "")
            } else {
                // 路径不存在或不是目录，显示错误提示但不中断，作为搜索处理
                return (nil, trimmed)
            }
        }
        
        // 处理路径过滤的情况（如 /bin 应该过滤 / 下面的 bin 目录）
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            let expandedPath = expandPath(trimmed)
            let url = URL(fileURLWithPath: expandedPath)
            let parentPath = url.deletingLastPathComponent().path
            let searchTerm = url.lastPathComponent
            
            // 验证父目录是否存在
            var parentIsDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: parentPath, isDirectory: &parentIsDirectory) && parentIsDirectory.boolValue {
                return (parentPath, searchTerm)
            }
        }
        
        // 其他情况都作为搜索查询处理
        return (nil, trimmed)
    }
    
    /// 获取当前显示路径（用于比较）
    private func getCurrentDisplayPath() -> String {
        let home = NSHomeDirectory()
        let displayPath: String
        if currentPath.hasPrefix(home) {
            displayPath = "~" + String(currentPath.dropFirst(home.count))
        } else {
            displayPath = currentPath
        }
        return displayPath.hasSuffix("/") ? displayPath : displayPath + "/"
    }
    
    /// 获取当前应该显示的查询字符串
    private func getCurrentDisplayQuery() -> String {
        if showStartPaths {
            return "/o "
        } else {
            let displayPath = getCurrentDisplayPath()
            return "/o \(displayPath)"
        }
    }
    
    /// 展开路径（处理 ~ 等符号）
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSString(string: path).expandingTildeInPath
        }
        return path
    }
    
    /// 更新当前路径并切换到文件浏览状态
    private func updateCurrentPath(_ newPath: String) {
        var isDirectory: ObjCBool = false
        
        // 验证路径是否存在且为目录
        if FileManager.default.fileExists(atPath: newPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // 路径存在且是目录，进行导航
                self.showStartPaths = false
                self.currentPath = newPath
                // currentPath 的 didSet 观察器会自动调用 updateQuery，无需重复调用
            } else {
                // 路径存在但不是目录
                print("错误: '\(newPath)' 不是一个目录")
                showPathError(message: "'\(URL(fileURLWithPath: newPath).lastPathComponent)' 不是一个目录")
            }
        } else {
            // 路径不存在
            print("错误: 路径 '\(newPath)' 不存在")
            showPathError(message: "路径 '\(newPath)' 不存在")
        }
    }
    
    /// 显示路径错误信息
    private func showPathError(message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "无法访问路径"
            alert.informativeText = message
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
