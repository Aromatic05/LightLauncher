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

    // 新增 Facade 属性
    lazy var facade: LauncherFacade = LauncherFacade(viewModel: self)

    // 插件激活状态
    private var activePlugin: Plugin?

    init() {
        setupControllers()
        switchController(from: nil, to: .launch)
        print("LauncherViewModel initialized with viewModel: \(self)")
        bindSearchText()
    }

    private func bindSearchText() {
        $searchText
            .sink { [weak self] text in
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }

    private func setupControllers() {
        controllers[.launch] = LaunchModeController()
        controllers[.kill] = KillModeController()
        controllers[.file] = FileModeController()
        controllers[.plugin] = PluginModeController()
        controllers[.search] = SearchModeController()
        controllers[.web] = WebModeController()
        controllers[.clip] = ClipModeController()
    }

    private func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        if let oldMode = oldMode, let oldController = controllers[oldMode] {
            oldController.cleanup(viewModel: self)
        }
        if let newController = controllers[newMode] {
            activeController = newController
            newController.enterMode(with: searchText, viewModel: self)
        }
        selectedIndex = 0
    }

    private func handleSearchTextChange(text: String) {
        updateCommandSuggestions(for: text)
        activeController?.handleInput(text, viewModel: self)
        _ = processInput(text)
    }

    private func updateCommandSuggestions(for text: String) {
        // print(searchText, text)
        if shouldShowCommandSuggestions() && text.hasPrefix("/") {
            let allCommands = getCommandSuggestions(for: text)
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

    // 命令建议本地实现
    private func getCommandSuggestions(for text: String) -> [LauncherCommand] {
        LauncherCommand.getCommandSuggestions(for: text)
    }
    private func shouldShowCommandSuggestions() -> Bool {
        SettingsManager.shared.showCommandSuggestions
    }

    func executeSelectedAction() -> Bool {
        print(searchText, searchText)
        guard let controller = activeController else { return false }
        return controller.executeAction(at: selectedIndex, viewModel: self)
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
        _ = processInput(command.trigger)
    }

    func moveCommandSuggestionUp() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : commandSuggestions.count - 1
    }

    func moveCommandSuggestionDown() {
        guard showCommandSuggestions && !commandSuggestions.isEmpty else { return }
        selectedIndex = selectedIndex < commandSuggestions.count - 1 ? selectedIndex + 1 : 0
    }

    // 插件相关接口全部转发到 PluginModeController
    func switchToPluginMode(with plugin: Plugin) {
        // (controllers[.plugin] as? PluginModeController)?.switchToPluginMode(with: plugin)
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
        displayableItems
    }

    // --- displayableItems 插槽 ---
    var displayableItems: [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }

    // --- 主输入分发与模式切换 ---
    /// 处理用户输入，根据输入内容切换模式或分发到当前模式控制器
    @discardableResult
    private func processInput(_ text: String) -> Bool {
        // 1. 命令建议（以/开头）优先处理
        if text.hasPrefix("/") {
            let inputCommand = text.components(separatedBy: " ").first ?? text
            let knownCommands = ["/k", "/s", "/w", "/t", "/o", "/v"]
            let pluginCommands = PluginManager.shared.getAllPlugins().map { $0.command }
            let allCommands = knownCommands + pluginCommands
            // 完全匹配内置或插件命令，切换到对应模式
            if let matched = allCommands.first(where: { $0 == inputCommand }) {
                if let mode = LauncherMode.fromPrefix(matched) {
                    modeSwitchIfNeeded(to: mode, text: text)
                    return true
                } else if pluginCommands.contains(matched) {
                    // 插件命令，切换到插件模式
                    self.mode = .plugin
                    // 激活插件等后续逻辑可在 PluginModeController 内部处理
                    return true
                }
            }
        }
        // 2. 检查当前模式是否应切回 launch
        if let controller = activeController, controller.shouldSwitchToLaunchMode(for: text) {
            switchToLaunchModeAndClear()
            if !text.hasPrefix("/") && !text.isEmpty {
                filterApps(searchText: text)
            }
            return true
        }
        // 3. 分发到当前模式控制器
        activeController?.handleInput(text, viewModel: self)
        return false
    }

    /// 切换模式（如有必要），并传递输入
    private func modeSwitchIfNeeded(to mode: LauncherMode, text: String) {
        if self.mode != mode {
            self.mode = mode
        }
        activeController?.enterMode(with: text, viewModel: self)
    }
}

// MARK: - ModeStateController 默认实现扩展
extension ModeStateController {
    func shouldSwitchToLaunchMode(for text: String) -> Bool {
        // 如果是以"/"开头的命令，需要更精确的匹配
        if let prefix = self.prefix, !prefix.isEmpty {
            if text.hasPrefix("/") {
                let inputCommand = text.components(separatedBy: " ").first ?? text
                let knownCommands = ["/k", "/s", "/w", "/t", "/o", "/v"]
                let pluginCommands = PluginManager.shared.getAllPlugins().map { $0.command }
                if knownCommands.contains(inputCommand) || pluginCommands.contains(inputCommand) {
                    return false
                }
                let allCommands = knownCommands + pluginCommands
                let hasMatchingPrefix = allCommands.contains { command in
                    command.hasPrefix(inputCommand) && command != inputCommand
                }
                if hasMatchingPrefix {
                    return false
                }
                if inputCommand != prefix && !inputCommand.hasPrefix(prefix + " ") {
                    return true
                }
            } else {
                if !text.hasPrefix(prefix) {
                    return true
                }
            }
        }
        return false
    }
    
    func extractSearchText(from text: String) -> String {
        guard let prefix = self.prefix, !prefix.isEmpty else { return text }
        if text.hasPrefix(prefix + " ") {
            return String(text.dropFirst(prefix.count + 1))
        } else if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }
}

extension LauncherMode {
    /// 根据前缀字符串返回对应模式
    static func fromPrefix(_ prefix: String) -> LauncherMode? {
        switch prefix {
        case "/k": return .kill
        case "/s": return .search
        case "/w": return .web
        case "/t": return .terminal
        case "/o": return .file
        case "/v": return .clip
        case "": return .launch
        default: return nil
        }
    }
}
