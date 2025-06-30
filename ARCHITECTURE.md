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

# LightLauncher 功能完成总结

## ✅ 已完成的功能

### 1. 新增功能模式
- **网页搜索 (/s)**: 使用默认搜索引擎搜索网络内容
- **网页打开 (/w)**: 快速打开网站或 URL，支持多种输入格式
- **终端执行 (/t)**: 在终端中执行命令，支持 Terminal 和 iTerm2

### 2. 设置界面改进
- 新增"功能模式"选项卡，独立管理所有模式设置
- 从通用设置中移除模式设置，提高界面组织性
- 每个模式都有详细的说明和配置选项

### 3. 配置文件集成
- 所有模式设置保存到 YAML 配置文件
- 支持旧版本配置文件的自动迁移
- 设置变更实时同步到配置文件
- 完善的配置文件注释说明

### 4. 架构优化
- **模块化设计**: 每个模式有独立的命令处理器
- **双向同步**: SettingsManager 和 ConfigManager 之间的设置同步
- **错误处理**: 完善的错误恢复和降级机制
- **向后兼容**: 自动处理配置文件版本升级

## 📁 新增的文件

```
Sources/
├── Commands/
│   ├── SearchCommand.swift     # 网页搜索命令处理器
│   ├── WebCommand.swift        # 网页打开命令处理器
│   └── TerminalCommand.swift   # 终端执行命令处理器
└── Views/
    └── LauncherView.swift      # 增加了 CommandInputView
```

## 🔧 修改的文件

1. **LauncherModes.swift**
   - 增加新的模式枚举
   - 扩展命令定义
   - 增加模式启用检查

2. **SettingsManager.swift**
   - 增加新模式的开关设置
   - 增加配置同步机制
   - 扩展模式切换方法

3. **ConfigManager.swift**
   - 增加模式配置结构
   - 增加配置迁移逻辑
   - 增加双向同步方法

4. **CommandProcessor.swift**
   - 注册新的命令处理器
   - 扩展模式切换逻辑
   - 增加帮助文本

5. **LauncherViewModel.swift**
   - 增加新模式的视图模型支持
   - 扩展模式切换方法
   - 增加命令建议功能

6. **SettingsView.swift**
   - 增加功能模式选项卡
   - 创建 ModeSettingsView
   - 移除通用设置中的模式设置

## 🎯 功能特性

### 交互体验
- 输入 `/` 显示所有可用命令提示
- 删除模式前缀自动返回启动模式
- 实时的命令状态显示
- 清晰的模式指示和帮助文本

### 设置管理
- 独立的功能模式选项卡
- 可视化的模式开关控制
- 实时的配置同步
- 详细的功能说明

### 配置持久化
- YAML 格式的人类可读配置
- 自动配置文件迁移
- 完善的注释说明
- 设置变更的实时保存

## 🔄 模式流程

1. **启动**: 用户输入 `/s`、`/w` 或 `/t`
2. **切换**: 进入对应模式，显示专用界面
3. **输入**: 用户继续输入内容
4. **执行**: 按回车执行对应操作
5. **返回**: 自动返回启动模式

## 📊 配置文件示例

```yaml
# LightLauncher 配置文件
hotKey:
  modifiers: 1024
  keyCode: 49
searchDirectories:
  - "/Applications"
  - "~/Applications"
modes:
  killModeEnabled: true
  searchModeEnabled: true
  webModeEnabled: true
  terminalModeEnabled: true
  showCommandSuggestions: true
  defaultSearchEngine: "google"
commonAbbreviations:
  ps: ["photoshop"]
  code: ["visual studio code"]
```

## 🎉 总结

成功实现了所有请求的功能：
- ✅ 网页搜索模式 (/s)
- ✅ 网页打开模式 (/w)  
- ✅ 终端执行模式 (/t)
- ✅ 独立的功能模式设置选项卡
- ✅ 配置文件集成
- ✅ 命令提示功能优化
- ✅ 设置界面重构

所有功能都经过完整的架构设计，具有良好的扩展性和维护性。用户可以通过设置界面灵活控制各个功能的启用状态，所有设置都会持久化保存到配置文件中。
