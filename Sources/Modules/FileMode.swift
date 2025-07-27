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
        if showStartPaths {
            let items = getStartPathItems(query: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        } else {
            let items = getFileItems(path: currentPath, query: arguments)
            self.displayableItems = items.map { $0 as any DisplayableItem }
        }
        if LauncherViewModel.shared.selectedIndex != 0 {
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
        self.displayableItems = []
        // Crucially, reset the internal state to its default
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
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
    
    @Published private var showStartPaths: Bool = true
    @Published private var currentPath: String = NSHomeDirectory()
    
    func navigateToDirectory(_ url: URL) {
        self.showStartPaths = false
        self.currentPath = url.path
        // Use the main input handler to load the new directory's contents
        self.handleInput(arguments: "")
    }

    func resetToStartScreen() {
        self.showStartPaths = true
        self.currentPath = NSHomeDirectory()
        self.handleInput(arguments: "")
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
        let allFiles = FileManager_LightLauncher.shared.getFiles(at: path)
        return FileManager_LightLauncher.shared.filterFiles(allFiles, query: query)
    }

    func openInFinder() {
        let url = URL(fileURLWithPath: currentPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
