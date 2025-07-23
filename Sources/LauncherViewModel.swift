import Foundation
import Combine
import AppKit

@MainActor
class LauncherViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// 单例实例
    static let shared = LauncherViewModel()
    
    /// 绑定到输入框的文本
    @Published var searchText = ""
    
    /// 在UI列表中当前选中的索引
    @Published var selectedIndex = 0
    
    /// 当前激活的模式，它的 `didSet` 会触发控制器切换
    @Published var mode: LauncherMode = .launch {
        didSet {
            // 当模式改变时，切换底层的控制器
            switchController(from: oldValue, to: mode)
        }
    }
    
    /// 用于命令建议的列表，现在使用 CommandRecord 作为数据源
    @Published var commandSuggestions: [CommandRecord] = []
    
    /// 控制命令建议浮层是否显示
    @Published var showCommandSuggestions = false
    
    /// 当前激活的控制器，UI通过它来获取要显示的项目
    @Published private(set) var activeController: (any ModeStateController)?
    
    /// 控制执行动作后是否隐藏窗口
    @Published var shouldHideWindowAfterAction = true
    
    /// 用于强制刷新UI的标志
    @Published var forceRefresh = false

    // MARK: - Private Properties

    /// 存储所有控制器实例的字典
    private(set) var controllers: [LauncherMode: any ModeStateController] = [:]
    
    /// 用于 Combine 订阅的存储器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    
    private init() {
        setupControllersAndRegisterCommands()
        // 初始时，直接设置 activeController，避免复杂的 didSet 逻辑
        self.activeController = controllers[.launch]
        bindSearchText()
    }

    /// 【已重构】初始化所有模式控制器，并将它们注册到 CommandRegistry
    private func setupControllersAndRegisterCommands() {
        let allControllers: [any ModeStateController] = [
            LaunchModeController.shared,
            KillModeController.shared,
            FileModeController.shared,
            PluginModeController.shared,
            SearchModeController.shared,
            WebModeController.shared,
            ClipModeController.shared,
            TerminalModeController.shared
        ]
        
        allControllers.forEach { controller in
            // 1. 将控制器实例存入本地字典
            controllers[controller.mode] = controller
            
            // 2. ✅ 将控制器注册到全局的命令注册中心
            CommandRegistry.shared.register(controller)
        }
    }

    // MARK: - Input Handling
    
    /// 绑定 searchText 的变化，并使用防抖来优化性能
    private func bindSearchText() {
        $searchText
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] text in
                // 当文本变化时，执行统一的处理逻辑
                self?.handleSearchTextChange(text: text)
            }
            .store(in: &cancellables)
    }

    /// 【已重构】处理搜索文本变化的核心方法
    private func handleSearchTextChange(text: String) {
        // 1. 检查并更新命令建议列表
        updateCommandSuggestions(for: text)
        
        // 2. 将输入分发给新的 processInput 函数处理
        processInput(text)
    }

    /// 【已重构】主输入分发逻辑，完全基于 CommandRegistry
   private func processInput(_ text: String) {
        
        // --- 场景 1: 输入为空 ---
        // 规则：只要输入框为空，就必须切换回默认的 launch 模式。
        if text.isEmpty {
            if self.mode != .launch {
                self.mode = .launch
            }
            // 让 LaunchModeController 处理空输入（例如：显示历史记录或常用应用）
            controllers[.launch]?.handleInput(arguments: "")
            return
        }
        
        // --- 场景 2: 输入匹配一个已注册的命令 ---
        // 规则：如果找到命令，则切换到该命令的模式，并把参数交给它。
        if let (record, arguments) = CommandRegistry.shared.findCommand(for: text) {
            modeSwitchIfNeeded(to: record.mode)
            record.controller.handleInput(arguments: arguments)
            return
        }
        
        // --- 场景 3: 输入不匹配任何命令 ---
        // 规则：如果当前不在 launch 模式，则强制切换回 launch 模式，
        //       并将当前输入全文交给 launch 模式处理（例如：作为应用搜索词）。
        if self.mode != .launch {
            self.mode = .launch
        }
        
        // 无论是本来就在 launch 模式，还是刚刚切换回来的，
        // 都由 launch 模式的控制器来处理这个“默认”输入。
        controllers[.launch]?.handleInput(arguments: text)
    }

    // MARK: - Mode & Controller Switching
    
    /// 【已重构】切换模式（如有必要），逻辑更纯粹
    private func modeSwitchIfNeeded(to newMode: LauncherMode) {
        if self.mode != newMode {
            self.mode = newMode
        }
    }

    /// 【已重构】当 `mode` 属性变化时，切换激活的控制器
    func switchController(from oldMode: LauncherMode?, to newMode: LauncherMode) {
        // 1. 清理即将离开的控制器状态
        if let oldMode = oldMode, let oldController = controllers[oldMode] {
            oldController.cleanup()
        }
        
        // 2. 设置新的激活控制器
        activeController = controllers[newMode]
        
        // 3. 重置选中索引
        selectedIndex = 0
        
        // ❌ 移除了 newController.enterMode(with: searchText)
        //    因为输入处理现在由 processInput 统一负责
    }

    // MARK: - UI Interaction
    
    /// 执行当前选中项的动作
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
    
    var displayableItems: [any DisplayableItem] {
        activeController?.displayableItems ?? []
    }

    var hasResults: Bool {
        return !displayableItems.isEmpty
    }
    
    // MARK: - Command Suggestions
    
    /// 【已重构】更新命令建议列表
    private func updateCommandSuggestions(for text: String) {
        if SettingsManager.shared.showCommandSuggestions && text.hasPrefix("/") {
            // 直接从重构后的 LauncherCommand 获取建议
            let newSuggestions = LauncherCommand.getSuggestions(for: text)
            
            if self.commandSuggestions.map({$0.prefix}) != newSuggestions.map({$0.prefix}) {
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

    /// 【已重构】应用选中的命令建议
    func applySelectedCommand(_ command: CommandRecord) {
        // 使用选中命令的前缀补全输入框，并加上空格
        searchText = command.prefix + " "
        
        // 立即隐藏建议列表
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


// ❌ MARK: - ModeStateController 默认实现扩展 (已删除)
// 这个扩展中的所有逻辑 (`shouldSwitchToLaunchMode`, `extractSearchText`)
// 现在都已过时，其功能被新的 CommandRegistry 和 handleDefault 方法取代。
// 因此，整个 extension 都应该被安全地删除。