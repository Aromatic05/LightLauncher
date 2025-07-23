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
    private var previousSearchText = ""

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
        $searchText
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                guard let self = self else { return }
                // 将新旧文本都传入处理函数
                self.handleSearchTextChange(newText: newText, oldText: self.previousSearchText)
                // 更新上一次的文本
                self.previousSearchText = newText
            }
            .store(in: &cancellables)
    }

    private func handleSearchTextChange(newText: String, oldText: String) {
        // 将新旧文本继续传递给建议更新函数
        updateCommandSuggestions(for: newText, oldText: oldText)
        processInput(newText)
    }

    private func processInput(_ text: String) {
        if text.isEmpty {
            if self.mode != .launch {
                self.mode = .launch
            }
            controllers[.launch]?.handleInput(arguments: "")
            return
        }
        if let (record, arguments) = CommandRegistry.shared.findCommand(for: text) {
            modeSwitchIfNeeded(to: record.mode)
            if record.mode == .plugin {
                if record.prefix == "/p" {
                    record.controller.handleInput(arguments: arguments)
                } else {
                    let fullPluginCommand = (record.prefix + " " + arguments).trimmingCharacters(
                        in: .whitespaces)
                    record.controller.handleInput(arguments: fullPluginCommand)
                }
            } else {
                record.controller.handleInput(arguments: arguments)
            }
            return
        }

        if self.mode != .launch {
            self.mode = .launch
        }

        controllers[.launch]?.handleInput(arguments: text)
    }

    // MARK: - Mode & Controller Switching
    private func modeSwitchIfNeeded(to newMode: LauncherMode) {
        if self.mode != newMode {
            self.mode = newMode
        }
    }

    func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        // 【修复】安全地解包可选的 oldMode
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
            .sink { [weak self] in
                self?.refreshID = UUID()
            }
        refreshID = UUID()
    }

    // MARK: - UI Interaction
    func executeSelectedAction() -> Bool {
        guard !displayableItems.isEmpty, selectedIndex >= 0, selectedIndex < displayableItems.count
        else { return false }
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
    private func updateCommandSuggestions(for text: String, oldText: String) {
        // 检查是否应该显示命令建议
        if SettingsManager.shared.showCommandSuggestions && (text.first != nil && !text.first!.isLetter) {
            let newSuggestions = LauncherCommand.getSuggestions(for: text)

            // 更新建议列表
            if self.commandSuggestions.map({ $0.prefix }) != newSuggestions.map({ $0.prefix }) {
                self.commandSuggestions = newSuggestions
            }
            let shouldShow = !newSuggestions.isEmpty
            if self.showCommandSuggestions != shouldShow {
                self.showCommandSuggestions = shouldShow
            }

            // --- 开始：自动补全逻辑 ---
            // 1. 检查是否只有一个建议
            if newSuggestions.count == 1, let suggestion = newSuggestions.first {
                // 2. 检查用户是否正在输入 (而不是删除)
                let isTypingForward = text.count > oldText.count
                // 3. 检查当前文本是否已经是补全后的命令 (防止重复补全)
                let isAlreadyCompleted = text == (suggestion.prefix + " ")

                // 4. 如果满足所有条件，则执行自动补全
                if isTypingForward && !isAlreadyCompleted {
                    // 使用 DispatchQueue.main.async 安全地更新 searchText
                    DispatchQueue.main.async {
                        self.searchText = suggestion.prefix + " "
                        self.showCommandSuggestions = false
                        self.commandSuggestions = []
                    }
                }
            }
            // --- 结束：自动补全逻辑 ---

        } else {
            // 如果文本不是以 "/" 开头，则清空建议
            if showCommandSuggestions { showCommandSuggestions = false }
            if !commandSuggestions.isEmpty { commandSuggestions = [] }
        }
    }

    func applySelectedCommand(_ command: CommandRecord) {
        searchText = command.prefix + " "
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
