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
        didSet {
            switchController(from: oldValue, to: mode)
        }
    }
    @Published var commandSuggestions: [CommandRecord] = []
    @Published var showCommandSuggestions = false
    @Published var shouldHideWindowAfterAction = true

    // MARK: - Core State & Data Source
    private(set) var controllers: [LauncherMode: any ModeStateController] = [:]
    @Published private(set) var activeController: (any ModeStateController)? {
        didSet {
            setupControllerSubscription()
        }
    }

    // MARK: - Refresh Signal System & Subscriptions
    @Published private var refreshID = UUID()
    private var controllerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    @Published var forceRefresh = false

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
            .sink { [weak self] text in
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }

    private func handleSearchTextChange(text: String) {
        updateCommandSuggestions(for: text)
        processInput(text)
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
                let fullPluginCommand = (record.prefix + " " + arguments).trimmingCharacters(
                    in: .whitespaces)
                record.controller.handleInput(arguments: fullPluginCommand)
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
    private func updateCommandSuggestions(for text: String) {
        if SettingsManager.shared.showCommandSuggestions && text.hasPrefix("/") {
            let newSuggestions = LauncherCommand.getSuggestions(for: text)
            if self.commandSuggestions.map({ $0.prefix }) != newSuggestions.map({ $0.prefix }) {
                self.commandSuggestions = newSuggestions
            }
            let shouldShow = !newSuggestions.isEmpty
            if self.showCommandSuggestions != shouldShow {
                self.showCommandSuggestions = shouldShow
            }
        } else {
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
