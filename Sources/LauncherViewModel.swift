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

    private(set) var controllers: [LauncherMode: any ModeStateController] = [:]
    @Published private(set) var activeController: (any ModeStateController)? {
        didSet {
            setupControllerSubscription()
            let rules = activeController?.interceptedKeys ?? []
            KeyboardEventHandler.shared.updateInterceptionRules(for: rules)
        }
    }

    @Published private var refreshID = UUID()
    private var controllerCancellable: AnyCancellable?
    var cancellables = Set<AnyCancellable>()
    private var previousSearchText = ""

    var displayableItems: [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }
    var hasResults: Bool {
        !displayableItems.isEmpty
    }

    var isCommandPressed: Bool = false
    var isOptionPressed: Bool = false
    var isControlPressed: Bool = false

    // MARK: - Initialization
    private init() {
        setupControllersAndRegisterCommands()
        self.activeController = controllers[.launch]
        setupControllerSubscription()
        bindSearchText()
        // 新增：启动时开始订阅键盘事件
        setupKeyboardSubscription()
        let initialRules = self.activeController?.interceptedKeys ?? []
        KeyboardEventHandler.shared.updateInterceptionRules(for: initialRules)
    }

    private func setupControllersAndRegisterCommands() {
        let allControllers: [any ModeStateController] = [
            LaunchModeController.shared, KillModeController.shared,
            FileModeController.shared, PluginModeController.shared,
            SearchModeController.shared, WebModeController.shared,
            ClipModeController.shared, TerminalModeController.shared,
            KeywordModeController.shared,
        ]
        allControllers.forEach { controller in
            controllers[controller.mode] = controller
            CommandRegistry.shared.register(controller)
        }
    }

    // MARK: - Keyboard Handling
    func setupKeyboardSubscription() {
        KeyboardEventHandler.shared.keyEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(keyEvent: event)
            }
            .store(in: &cancellables)
    }

    private func handle(keyEvent: KeyEvent) {
        switch keyEvent {
        case .arrowUp:
            if showCommandSuggestions {
                guard !commandSuggestions.isEmpty else { return }
                selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
            } else {
                guard !displayableItems.isEmpty else { return }
                selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : displayableItems.count - 1
            }
            return
        case .arrowDown:
            if showCommandSuggestions {
                guard !commandSuggestions.isEmpty else { return }
                selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
            } else {
                guard !displayableItems.isEmpty else { return }
                selectedIndex = selectedIndex < displayableItems.count - 1 ? selectedIndex + 1 : 0
            }
            return
        case .enter:
            if showCommandSuggestions {
                guard !commandSuggestions.isEmpty else { return }
                let selectedCommand = commandSuggestions[selectedIndex]
                applySelectedCommand(selectedCommand)
            } else {
                if executeSelectedAction(at: selectedIndex) {
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                }
            }
            return
        case .escape:
            NotificationCenter.default.post(name: .hideWindow, object: nil)
            return
        default: break
        }

        switch keyEvent {
        case .commandFlagChanged(let isPressed): isCommandPressed = isPressed
        case .optionFlagChanged(let isPressed): isOptionPressed = isPressed
        case .controlFlagChanged(let isPressed): isControlPressed = isPressed
        default: break
        }

        if activeController?.handle(keyEvent: keyEvent) == true {
            return
        }
    }

    // MARK: - Input Handling
    private func bindSearchText() {
        $searchText
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                guard let self = self else { return }
                self.handleSearchTextChange(newText: newText, oldText: self.previousSearchText)
                self.previousSearchText = newText
            }
            .store(in: &cancellables)
    }

    private func handleSearchTextChange(newText: String, oldText: String) {
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

    func updateQuery(newQuery text: String) {
        DispatchQueue.main.async {
            self.searchText = text
            self.showCommandSuggestions = false
            self.commandSuggestions = []
        }
    }

    func clearSearch() {
        updateQuery(newQuery: "")
    }

    // MARK: - Command Suggestions (UNCHANGED)
    private func updateCommandSuggestions(for text: String, oldText: String) {
        if SettingsManager.shared.showCommandSuggestions
            && (text.first != nil && !text.first!.isLetter)
        {
            let newSuggestions = LauncherCommand.getSuggestions(for: text)
            if self.commandSuggestions.map({ $0.prefix }) != newSuggestions.map({ $0.prefix }) {
                self.commandSuggestions = newSuggestions
            }
            let shouldShow = !newSuggestions.isEmpty
            if self.showCommandSuggestions != shouldShow {
                self.showCommandSuggestions = shouldShow
            }

            if newSuggestions.count == 1, let suggestion = newSuggestions.first {
                let isTypingForward = text.count > oldText.count
                let isAlreadyCompleted = text == (suggestion.prefix + " ")
                if isTypingForward && !isAlreadyCompleted {
                    self.updateQuery(newQuery: suggestion.prefix + " ")
                }
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

    func executeSelectedAction(at index: Int) -> Bool {
        guard !displayableItems.isEmpty, index >= 0, index < displayableItems.count
        else { return false }
        return displayableItems[index].executeAction()
    }
}
