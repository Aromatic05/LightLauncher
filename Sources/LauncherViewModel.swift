import Foundation
import Combine
import AppKit

@MainActor
class LauncherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var mode: LauncherMode = .launch {
        didSet {
            switchController(from: oldValue, to: mode)
        }
    }
    @Published var commandSuggestions: [LauncherCommand] = []
    @Published var showCommandSuggestions = false
    @Published private(set) var activeController: (any ModeStateController)?

    var controllers: [LauncherMode: any ModeStateController] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let commandProcessor = MainCommandProcessor()

    // 新增 Facade 属性
    lazy var facade: LauncherFacade = LauncherFacade(viewModel: self)

    // 插件激活状态
    private var activePlugin: Plugin?

    init() {
        setupControllers()
        ProcessorRegistry.shared.setMainProcessor(commandProcessor)
        registerAllProcessors()
        switchController(from: nil, to: .launch)
    }

    private func setupControllers() {
        controllers[.launch] = LaunchStateController()
        controllers[.kill] = KillStateController()
        controllers[.file] = FileStateController()
        controllers[.plugin] = PluginStateController()
        controllers[.search] = SearchStateController()
        controllers[.web] = WebStateController()
        controllers[.clip] = ClipStateController()
    }

    private func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        if let oldMode = oldMode, let oldController = controllers[oldMode] {
            oldController.deactivate()
        }
        if let newController = controllers[newMode] {
            activeController = newController
            newController.activate()
            newController.update(for: searchText)
        }
        selectedIndex = 0
    }

    private func handleSearchTextChange(text: String) {
        updateCommandSuggestions(for: text)
        activeController?.update(for: text)
        _ = commandProcessor.processInput(text, in: self)
    }

    private func updateCommandSuggestions(for text: String) {
        if commandProcessor.shouldShowCommandSuggestions() && text.hasPrefix("/") {
            let allCommands = commandProcessor.getCommandSuggestions(for: text)
            if text.count > 1 {
                let searchPrefix = text.lowercased()
                commandSuggestions = allCommands.filter { command in
                    command.trigger.lowercased().hasPrefix(searchPrefix) ||
                    command.description.lowercased().contains(searchPrefix.dropFirst())
                }
            } else {
                commandSuggestions = allCommands
            }
            showCommandSuggestions = !commandSuggestions.isEmpty
            if !commandSuggestions.isEmpty {
                selectedIndex = 0
            }
        } else {
            showCommandSuggestions = false
            commandSuggestions = []
        }
    }

    func executeSelectedAction() -> Bool {
        guard let controller = activeController else { return false }
        if let postAction = controller.executeAction(at: selectedIndex) {
            if postAction == .hideWindow {
                hideLauncher()
            }
            return true
        }
        return false
    }

    func moveSelectionUp() {
        guard let items = activeController?.displayableItems, !items.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : items.count - 1
    }

    func moveSelectionDown() {
        guard let items = activeController?.displayableItems, !items.isEmpty else { return }
        selectedIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
    }

    var hasResults: Bool {
        return !(activeController?.displayableItems.isEmpty ?? true)
    }

    private func registerAllProcessors() {
        let launchProcessor = LaunchCommandProcessor()
        let launchModeHandler = LaunchModeHandler()
        commandProcessor.registerProcessor(launchProcessor)
        commandProcessor.registerModeHandler(launchModeHandler)
        let killProcessor = KillCommandProcessor()
        let killModeHandler = KillModeHandler()
        commandProcessor.registerProcessor(killProcessor)
        commandProcessor.registerModeHandler(killModeHandler)
        let searchProcessor = SearchCommandProcessor()
        let searchModeHandler = SearchModeHandler()
        commandProcessor.registerProcessor(searchProcessor)
        commandProcessor.registerModeHandler(searchModeHandler)
        let webProcessor = WebCommandProcessor()
        let webModeHandler = WebModeHandler()
        commandProcessor.registerProcessor(webProcessor)
        commandProcessor.registerModeHandler(webModeHandler)
        let terminalProcessor = TerminalCommandProcessor()
        let terminalModeHandler = TerminalModeHandler()
        commandProcessor.registerProcessor(terminalProcessor)
        commandProcessor.registerModeHandler(terminalModeHandler)
        let fileProcessor = FileCommandProcessor()
        let fileModeHandler = FileModeHandler()
        commandProcessor.registerProcessor(fileProcessor)
        commandProcessor.registerModeHandler(fileModeHandler)
        let pluginProcessor = PluginCommandProcessor()
        commandProcessor.registerProcessor(pluginProcessor)
        commandProcessor.registerModeHandler(pluginProcessor)
        let clipProcessor = ClipCommandProcessor()
        let clipModeHandler = ClipModeHandler()
        commandProcessor.registerProcessor(clipProcessor)
        commandProcessor.registerModeHandler(clipModeHandler)
    }
    func hideLauncher() {
        NotificationCenter.default.post(name: .hideWindow, object: nil)
    }

    // --- 交互与命令建议相关方法 ---
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }

    func applySelectedCommand(_ command: LauncherCommand) {
        searchText = command.trigger + " "
        showCommandSuggestions = false
        commandSuggestions = []
        selectedIndex = 0
        _ = commandProcessor.processInput(command.trigger, in: self)
    }

    func moveCommandSuggestionUp() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
    }

    func moveCommandSuggestionDown() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
    }

    // 插件相关接口全部转发到 PluginStateController
    func switchToPluginMode(with plugin: Plugin) {
        (controllers[.plugin] as? PluginStateController)?.switchToPluginMode(with: plugin)
        mode = .plugin
        activePlugin = plugin
        selectedIndex = 0
    }

    // 命令建议相关
    func selectCurrentCommandSuggestion() -> Bool {
        guard showCommandSuggestions,
              selectedIndex >= 0,
              selectedIndex < commandSuggestions.count else { return false }
        let selectedCommand = commandSuggestions[selectedIndex]
        applySelectedCommand(selectedCommand)
        return true
    }

    // 兼容接口：获取当前模式下所有可显示项
    func getCurrentItems() -> [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }
}
