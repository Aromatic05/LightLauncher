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
        bindSearchText()
    }

    private func bindSearchText() {
        $searchText
            // 处理搜索文本变化，使用防抖机制
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
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
        controllers[.terminal] = TerminalModeController() // 补全 terminal 模式 controller
    }

    private func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        if let oldMode = oldMode, let oldController = controllers[oldMode] {
            oldController.cleanup(viewModel: self)
        }
        // 保证 .launch 模式下 controller 永远有效
        if let newController = controllers[newMode] {
            activeController = newController
            newController.enterMode(with: searchText, viewModel: self)
        } else if newMode == .launch {
            let launchController = LaunchModeController()
            controllers[.launch] = launchController
            activeController = launchController
            launchController.enterMode(with: searchText, viewModel: self)
        } else {
            activeController = nil
        }
        selectedIndex = 0
    }

    private func handleSearchTextChange(text: String) {
        updateCommandSuggestions(for: text)
        activeController?.handleInput(text, viewModel: self)
        _ = processInput(text)
    }

    private func updateCommandSuggestions(for text: String) {
        if shouldShowCommandSuggestions() && text.hasPrefix("/") {
            let allCommands = getCommandSuggestions(for: text)
            let newSuggestions: [LauncherCommand]
            if text.count > 1 {
                let searchPrefix = text.lowercased()
                newSuggestions = allCommands.filter { command in
                    command.trigger.lowercased().hasPrefix(searchPrefix) ||
                    command.description.lowercased().contains(searchPrefix.dropFirst())
                }
            } else {
                newSuggestions = allCommands
            }
            let shouldShow = !newSuggestions.isEmpty
            // 防抖：只有变化时才 set
            let isSame = commandSuggestions.elementsEqual(newSuggestions) { $0.trigger == $1.trigger }
            if !isSame {
                commandSuggestions = newSuggestions
            }
            if showCommandSuggestions != shouldShow {
                showCommandSuggestions = shouldShow
            }
            if shouldShow && selectedIndex != 0 {
                selectedIndex = 0
            }
        } else {
            if showCommandSuggestions {
                showCommandSuggestions = false
            }
            if !commandSuggestions.isEmpty {
                commandSuggestions = []
            }
            // 修复：命令建议消失时重置 selectedIndex
            if selectedIndex != 0 {
                selectedIndex = 0
            }
        }
    }

    // 命令建议本地实现
    private func getCommandSuggestions(for text: String) -> [LauncherCommand] {
        return LauncherCommand.getCommandSuggestions(for: text)
    }
    private func shouldShowCommandSuggestions() -> Bool {
        return SettingsManager.shared.showCommandSuggestions
    }

    func executeSelectedAction() -> Bool {
        guard !displayableItems.isEmpty, selectedIndex >= 0, selectedIndex < displayableItems.count else { return false }
        return activeController?.executeAction(at: selectedIndex, viewModel: self) ?? false
    }

    func moveSelectionUp() {
        guard !displayableItems.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : displayableItems.count - 1
    }

    func moveSelectionDown() {
        guard !displayableItems.isEmpty else { return }
        selectedIndex = selectedIndex < displayableItems.count - 1 ? selectedIndex + 1 : 0
    }

    var hasResults: Bool {
        return !displayableItems.isEmpty
    }

    func hideLauncher() {
        NotificationCenter.default.post(name: .hideWindow, object: nil)
    }

    // --- 交互与命令建议相关方法 ---
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }

    func switchToLaunchModeAndClear() {
        mode = .launch // 关键：同步切换模式
        if let controller = controllers[.launch] {
            activeController = controller
            controller.enterMode(with: "", viewModel: self)
        }
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

    // 新增：displayableItems 只读属性，转发到 activeController
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
            // 只有完全匹配有效命令时才切换模式
            if allCommands.contains(inputCommand) {
                if let mode = LauncherMode.fromPrefix(inputCommand) {
                    modeSwitchIfNeeded(to: mode, text: text)
                    return true
                } else if pluginCommands.contains(inputCommand) {
                    self.mode = .plugin
                    return true
                }
            }
            // 如果只输入了 '/'，不切换模式，直接返回
            if inputCommand == "/" {
                return false
            }
        }
        // 2. 检查当前模式是否应切回 launch
        if let controller = activeController, controller.shouldSwitchToLaunchMode(for: text) {
            switchToLaunchModeAndClear()
            if !text.hasPrefix("/") && !text.isEmpty {
                if let launchController = controllers[.launch] as? LaunchModeController {
                    launchController.filterApps(searchText: text, viewModel: self)
                }
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
        if let prefix = self.prefix, !prefix.isEmpty {
            if text.hasPrefix("/") {
                let inputCommand = text.components(separatedBy: " ").first ?? text
                let knownCommands = ["/k", "/s", "/w", "/t", "/o", "/v"]
                let pluginCommands = PluginManager.shared.getAllPlugins().map { $0.command }
                let allCommands = knownCommands + pluginCommands
                let should = !allCommands.contains(inputCommand) && inputCommand != prefix
                if should {
                    return true
                }
                return false
            } else {
                let should = !text.hasPrefix(prefix)
                if should {
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
