# LightLauncher 项目架构优化

## 新的项目结构

### 核心文件结构
```
Sources/
├── main.swift
├── AppDelegate.swift
├── ConfigManager.swift
├── SettingsManager.swift
├── SettingsView.swift
├── AppScanner.swift
├── LauncherModes.swift          # 新增：模式和数据结构定义
├── CommandProcessor.swift       # 新增：命令处理器
├── LauncherViewModel.swift      # 重构：使用新架构
├── Commands/                    # 新增：命令实现目录
│   ├── LaunchCommand.swift
│   └── KillCommand.swift
└── Views/                       # 新增：视图组件目录
    ├── LauncherView.swift       # 重构：主视图
    ├── LauncherComponents.swift # 新增：头部、搜索框等组件
    └── AppRowViews.swift        # 新增：应用行视图组件
```

## 架构改进

### 1. 模式系统 (`LauncherModes.swift`)
- `LauncherMode` 枚举：定义所有可用模式（launch, kill）
- `LauncherCommand` 结构：定义命令触发器和描述
- `AppInfo` 和 `RunningAppInfo`：统一的数据结构
- `ModeData` 协议：为不同模式提供统一的数据接口

### 2. 命令处理系统 (`CommandProcessor.swift`)
- `CommandProcessor` 协议：定义命令处理器接口
- `MainCommandProcessor`：主命令分发器
- `LaunchCommandProcessor`：处理启动相关命令
- `KillCommandProcessor`：处理关闭应用命令
- `CommandSuggestionProvider`：提供命令建议和帮助文本

### 3. 具体命令实现 (`Commands/`)
- `LaunchCommand.swift`：启动应用命令实现
- `KillCommand.swift`：关闭应用命令实现和运行应用管理器
- 每个命令都实现 `LauncherCommandHandler` 协议

### 4. 视图组件化 (`Views/`)
- `LauncherView.swift`：主视图，组合各个组件
- `LauncherComponents.swift`：可重用的UI组件
  - `LauncherHeaderView`：头部标题组件
  - `SearchBoxView`：搜索框组件
  - `EmptyStateView`：空状态显示组件
- `AppRowViews.swift`：应用行视图组件
  - `AppRowView`：普通应用行
  - `RunningAppRowView`：运行应用行

## 扩展性

### 添加新命令的步骤

1. **在 `LauncherModes.swift` 中添加新模式**：
```swift
enum LauncherMode: String, CaseIterable {
    case launch = "launch"
    case kill = "kill"
    case newMode = "newMode"  // 新模式
}
```

2. **在 `LauncherModes.swift` 中添加新命令**：
```swift
static let allCommands: [LauncherCommand] = [
    LauncherCommand(trigger: "/k", mode: .kill, description: "Kill apps"),
    LauncherCommand(trigger: "/n", mode: .newMode, description: "New feature")  // 新命令
]
```

3. **在 `Commands/` 目录创建新命令实现**：
```swift
// Commands/NewCommand.swift
struct NewCommand: LauncherCommandHandler {
    let trigger = "/n"
    let description = "New feature description"
    let mode = LauncherMode.newMode
    
    func execute(in viewModel: LauncherViewModel) -> Bool {
        // 实现命令逻辑
    }
    
    func handleInput(_ text: String, in viewModel: LauncherViewModel) {
        // 处理搜索输入
    }
    
    func executeSelection(at index: Int, in viewModel: LauncherViewModel) -> Bool {
        // 执行选中项
    }
}
```

4. **在 `CommandProcessor.swift` 中注册新处理器**：
```swift
private func setupProcessors() {
    processors = [
        LaunchCommandProcessor(),
        KillCommandProcessor(),
        NewCommandProcessor()  // 新处理器
    ]
}
```

5. **如果需要新的视图组件，在 `Views/` 目录添加**

## 优势

1. **模块化**：每个功能都有独立的文件和责任
2. **可扩展**：新增命令只需添加对应的处理器和命令实现
3. **可维护**：代码结构清晰，职责分离
4. **可重用**：视图组件可以在不同模式间重用
5. **类型安全**：使用协议和枚举确保类型安全

## 当前实现的功能

- `/k` 命令：进入关闭模式，可以搜索并关闭运行中的应用
- 模式切换：在启动模式和关闭模式间自动切换
- 统一的键盘导航和选择机制
- 分离的视图组件，便于维护和测试

## 未来可扩展的功能

- `/s` 命令：系统设置快捷访问
- `/f` 命令：文件搜索
- `/c` 命令：计算器功能
- `/w` 命令：网页搜索
- `/h` 命令：帮助和命令列表

这种架构设计使得添加新功能变得简单和一致，同时保持代码的整洁和可维护性。
