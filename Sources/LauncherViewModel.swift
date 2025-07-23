import AppKit
import Combine
import Foundation

@MainActor
class LauncherViewModel: ObservableObject {
    static let shared = LauncherViewModel()

    // MARK: - Published Properties for UI Binding
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var mode: LauncherMode = .launch {
        didSet { switchController(from: oldValue, to: mode) }
    }
    @Published var commandSuggestions: [CommandRecord] = []
    @Published var showCommandSuggestions = false
    @Published var shouldHideWindowAfterAction = true

    // MARK: - Core State & Data Source
    private(set) var controllers: [LauncherMode: any ModeStateController] = [:]
    @Published private(set) var activeController: (any ModeStateController)? {
        didSet { setupControllerSubscription() }
    }

    // MARK: - Refresh Signal System & Subscriptions
    @Published private var refreshID = UUID()
    private var controllerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // ✅ 新增：一个标志位，用于防止在自动补全后立即再次触发补全
    private var justAutoCompleted = false

    var displayableItems: [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }
    var hasResults: Bool {
        !displayableItems.isEmpty
    }

    // MARK: - Initialization
    private init() {
        setupControllersAndRegisterCommands()
        self.activeController = controllers[.launch]
        setupControllerSubscription()
        bindSearchText()
    }

    private func setupControllersAndRegisterCommands() {
        let allControllers: [any ModeStateController] = [
            LaunchModeController.shared, KillModeController.shared,
            FileModeController.shared, PluginModeController.shared,
            SearchModeController.shared, WebModeController.shared,
            ClipModeController.shared, TerminalModeController.shared,
        ]
        allControllers.forEach { controller in
            controllers[controller.mode] = controller
            CommandRegistry.shared.register(controller)
        }
    }

    // MARK: - Input Handling
    private func bindSearchText() {
        // ✅ 修改：不再使用 debounce，而是用 .removeDuplicates 来防止重复处理
        // 这样可以保证 updateCommandSuggestions 的即时性
        $searchText
            .removeDuplicates() // 只有当文本真正改变时才触发
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }

    private func handleSearchTextChange(text: String) {
        // ✅ updateCommandSuggestions 现在会同步执行，并且可能改变 searchText
        updateCommandSuggestions(for: text)
        // ✅ processInput 也同步执行，保证 UI 状态一致
        processInput(self.searchText) // 使用 self.searchText，因为它可能已被补全
    }

    private func processInput(_ text: String) {
        if text.isEmpty {
            if self.mode != .launch { self.mode = .launch }
            controllers[.launch]?.handleInput(arguments: "")
            return
        }
        if let (record, arguments) = CommandRegistry.shared.findCommand(for: text) {
            modeSwitchIfNeeded(to: record.mode)
            if record.mode == .plugin {
                if record.prefix == "/p" {
                    record.controller.handleInput(arguments: arguments)
                } else {
                    let fullPluginCommand = (record.prefix + " " + arguments).trimmingCharacters(in: .whitespaces)
                    record.controller.handleInput(arguments: fullPluginCommand)
                }
            } else {
                record.controller.handleInput(arguments: arguments)
            }
            return
        }
        if self.mode != .launch { self.mode = .launch }
        controllers[.launch]?.handleInput(arguments: text)
    }

    // MARK: - Mode & Controller Switching
    private func modeSwitchIfNeeded(to newMode: LauncherMode) {
        if self.mode != newMode { self.mode = newMode }
    }

    func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        if let mode = oldMode, let oldController = controllers[mode] {
            oldController.cleanup()
        }
        activeController = controllers[newMode]
        selectedIndex = 0
    }

    private func setupControllerSubscription() {
        controllerCancellable?.cancel()
        guard let controller = activeController else { return }
        controllerCancellable = controller.dataDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshID = UUID() }
        refreshID = UUID()
    }

    // MARK: - UI Interaction
    func executeSelectedAction() -> Bool {
        guard !displayableItems.isEmpty, selectedIndex >= 0, selectedIndex < displayableItems.count else { return false }
        return activeController?.executeAction(at: selectedIndex) ?? false
    }

    func moveSelectionUp() {
        guard !displayableItems.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : displayableItems.count - 1
    }

    func moveSelectionDown() {
        guard !displayableItems.isEmpty else { return }
        selectedIndex = selectedIndex < displayableItems.count - 1 ? selectedIndex + 1 : 0
    }

    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }

    func hideLauncher() {
        NotificationCenter.default.post(name: .hideWindow, object: nil)
    }

    // MARK: - Command Suggestions
    
    /// ✅ 【已增强】现在包含自动补全逻辑
    private func updateCommandSuggestions(for text: String) {
        // 如果刚刚执行了自动补全，则跳过此次处理，防止循环
        if justAutoCompleted {
            justAutoCompleted = false
            return
        }
        
        if SettingsManager.shared.showCommandSuggestions && text.hasPrefix("/") {
            let newSuggestions = LauncherCommand.getSuggestions(for: text)
            if self.commandSuggestions.map({ $0.prefix }) != newSuggestions.map({ $0.prefix }) {
                self.commandSuggestions = newSuggestions
            }
            let shouldShow = !newSuggestions.isEmpty
            if self.showCommandSuggestions != shouldShow {
                self.showCommandSuggestions = shouldShow
            }
            
            // --- ✅ 自动补全逻辑 ---
            // 1. 只有一条建议
            // 2. 并且当前输入文本完全等于该建议的前缀
            if newSuggestions.count == 1, let uniqueSuggestion = newSuggestions.first, uniqueSuggestion.prefix == text {
                // 调用补全方法
                applySelectedCommand(uniqueSuggestion, isAutoCompletion: true)
            }
            
        } else {
            if showCommandSuggestions { showCommandSuggestions = false }
            if !commandSuggestions.isEmpty { commandSuggestions = [] }
        }
    }

    /// ✅ 【已增强】现在可以处理自动补全的情况
    func applySelectedCommand(_ command: CommandRecord, isAutoCompletion: Bool = false) {
        // 如果是自动补全，设置标志位
        if isAutoCompletion {
            self.justAutoCompleted = true
        }
        
        // 补全文本
        searchText = command.prefix + " "
        
        // 隐藏建议列表
        showCommandSuggestions = false
        commandSuggestions = []
    }

    func moveCommandSuggestionUp() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
    }

    func moveCommandSuggestionDown() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
    }
}