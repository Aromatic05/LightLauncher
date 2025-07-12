# 插件模式计划书
# 一、项目目标

LightLauncher 支持插件扩展，允许用户和开发者通过插件增强启动器功能，实现个性化和多样化的应用场景。

# 二、插件架构设计
9. 插件模式执行器

   `PluginMode.swift` 是插件模式下对 `ModeStateController` 协议的实现，是插件统一入口和调度核心。

   #### 主要属性（仅插件模式拥有）
   - `allPluginInstances: [String: PluginInstance]`：保存所有已加载插件的运行时实例，key 为插件名称。
   - `commandMap: [String: String]`：插件命令到插件名称的映射，支持命令唤起。
   - `activePlugin: PluginInstance?`：当前激活的插件实例，根据输入动态切换。
   - `lastInput: String`：记录最近一次输入内容，便于插件间切换和状态恢复。
   - `helpTexts: [String]`：聚合所有插件的帮助信息，供 UI 展示。

   #### 插件模式下各协议方法的具体功能
   - `static var shared: Self { get }`：插件模式全局唯一实例，负责统一调度所有插件实例和命令。
   - `var displayableItems: [any DisplayableItem] { get }`：当前激活插件返回的所有结果项，自动聚合并供 UI 展示。
   - `var displayName: String { get }`：插件模式名称，通常为“插件”或“Plugin”。
   - `var iconName: String { get }`：插件模式图标，主界面统一展示。
   - `var placeholder: String { get }`：输入框提示，动态切换为当前激活插件的 placeholder。
   - `var modeDescription: String? { get }`：插件模式描述，展示插件统一入口说明。
   - `var prefix: String? { get }`：插件模式触发前缀（如 /p），用于快速进入插件模式。

   - `func shouldActivate(for text: String) -> Bool`：判断输入是否应进入插件模式（如前缀匹配或命令匹配），并自动唤起对应插件。
   - `func enterMode(with text: String)`：进入插件模式时，初始化所有插件实例状态，重置 activePlugin，准备命令列表和帮助信息。
   - `func handleInput(_ text: String)`：根据输入内容，自动匹配插件命令，激活对应插件，将输入传递给插件进行处理（如搜索、过滤、API调用等），并更新 lastInput。
   - `func executeAction(at index: Int) -> Bool`：执行当前激活插件返回的结果项对应的动作（如打开、复制、跳转等），并根据插件返回值决定是否关闭窗口或继续。
   - `func shouldExit(for text: String) -> Bool`：判断是否应退出插件模式（如输入清空、切换前缀、插件主动请求退出等），并清理 activePlugin。
   - `func cleanup()`：插件模式退出或切换时，清理所有插件实例状态、释放资源、重置 UI。
   - `func makeRowView(for item: any DisplayableItem, isSelected: Bool, index: Int, handleItemSelection: @escaping (Int) -> Void) -> AnyView`：根据当前激活插件的结果项，生成统一风格的行视图，支持插件自定义 UI。
   - `func makeContentView() -> AnyView`：生成插件模式下的主内容视图，聚合所有插件的内容展示。
   - `static func getHelpText() -> [String]`：返回插件模式下所有插件的帮助信息，供用户快速了解插件命令和用法。
# 插件架构采用分层设计，主要包括以下模块：

1. 插件存储与分发
   - 内置插件存放于 LightLauncher.app 程序包内部（如 `LightLauncher.app/Contents/Plugins/`），随主程序分发，用户不可直接修改。
   - 外置插件统一放置于 `~/.config/LightLauncher/plugins/`，支持用户自定义安装和管理。

2. 插件核心管理
   - `PluginManager.swift` 负责所有插件的注册、启用状态、统一调度，采用单例模式。
   - `PluginLoader.swift` 负责单个插件的加载与初始化，采用单例模式，保证加载一致性。
   - `PluginExecutor.swift` 提供插件执行环境，支持 JS/Swift 等多语言插件。
   - `PluginConfigManager.swift` 管理插件配置的读取与写入。
   - `PluginPermissionManager.swift` 负责插件权限校验与管理。

3. 插件模型层
   - `Plugin.swift` 定义插件内容与元信息，解析 manifest.yaml，管理脚本、配置、权限等。
   - `PluginInstance.swift` 管理插件运行时实例，包括 JSContext、API 管理器、启用状态等。
   - `PluginItem.swift` 实现 DisplayableItem 协议，统一插件结果项展示，支持批量、分页等。
   - `PluginError.swift` 定义插件相关错误类型，覆盖加载、执行、配置、权限、API、脚本等各环节。

4. 插件 API 层
   - `APIManager.swift` 统一调度插件 API，支持异步调用。
   - 插件通过 manifest.yaml 显式声明所需权限，API 粒度控制访问。
   - 所有敏感 API（如文件读写、剪贴板、网络等）均需权限声明，未授权时拒绝调用。

5. 插件视图层
   - 插件相关 UI 组件在 `Sources/Plugins/Views/` 实现，如 `PluginItemRowView.swift`、`PluginModeView.swift`。
   - 支持插件自定义部分界面，主程序负责统一风格和安全性。

6. 插件配置与数据
   - 插件总配置文件 `~/.config/LightLauncher/plugins.yaml`，管理插件列表、命令、启用状态等，自动生成和重建。
   - 插件独立配置文件 `~/.config/LightLauncher/configs/插件名.yaml`，每插件一个，自动从样例配置复制。
   - 插件数据目录 `~/.config/LightLauncher/data/插件名/`，插件可自由读写，无需权限。

7. 插件协议与扩展性
   - 所有插件需实现 `ModeStateController` 协议，保证模式切换、输入处理、UI 展示等一致性。
   - 协议要求实现单例访问、元信息、输入处理、动作执行、结果展示、帮助文本等方法。

8. 插件错误处理
   - 插件系统通过 `PluginError` 类型贯穿加载、执行、API调用等环节，支持详细错误描述和定位。

整体架构关系：
插件存储与分发负责插件的物理位置和生命周期管理，核心管理层负责插件的注册、加载、执行、权限、配置，模型层负责插件数据和运行时状态，API 层负责插件与主程序的安全交互，视图层负责统一和自定义 UI 展示，配置与数据层负责插件参数和持久化，协议层保证插件扩展性和一致性，错误处理层保证系统健壮性。

# 三、插件生命周期

1. 加载：主程序启动时扫描 `TestPlugins/`，通过 `PluginLoader` 加载插件。
2. 配置：通过 `PluginConfigManager` 读取和管理插件配置。
3. 权限：`PluginPermissionManager` 控制插件访问敏感资源。
4. 执行：`PluginExecutor` 负责插件的运行与回调。
5. 卸载：支持插件动态卸载与热更新。

# 四、插件开发规范

- 插件目录结构规范：

1. 内置插件：存放于 LightLauncher.app 程序包的内部（如 `LightLauncher.app/Contents/Plugins/`），随主程序一同分发和升级，用户不可直接修改。
2. 外置插件：统一放置于 `~/.config/LightLauncher/plugins/` 目录。
3. 插件总配置文件：`~/.config/LightLauncher/plugins.yaml`，用于快速加载插件列表，包含插件命令、是否启用、插件名称等一系列重要信息。主程序启动时自动读取该文件，无则自动生成，添加或删除插件时会自动重建，确保插件信息实时同步。
4. 插件独立配置文件：`~/.config/LightLauncher/configs/插件名.yaml`，每个插件一个，存储插件专属配置。
5. 插件数据目录：`~/.config/LightLauncher/data/插件名/`，每个插件一个目录，插件可自由读写自身数据目录，无需额外权限。

每个插件需包含：
- `manifest.yaml`（清单）：声明插件元信息、权限、入口等。
- `main.js`（主入口）：插件主逻辑文件。
- 样例配置文件（`example_config.yaml`）：作为模板，安装插件时自动复制到 `~/.config/LightLauncher/configs/插件名.yaml`，用户可在此基础上修改实际配置。

注意：样例配置文件不可直接修改，实际配置需在独立配置文件中完成。
- 插件需实现标准 API（见 `PluginAPI.swift`），与主程序通信。
- 插件可通过 API 访问剪贴板、文件、搜索、窗口等功能，受权限控制。
- 推荐插件文档与示例放在插件目录下。


# 五、核心模块说明
- `PluginMode.swift`：插件模式的执行器，实现 `ModeStateController` 协议，负责管理所有插件实例、命令唤起、插件统一入口、输入处理、结果展示等，是插件模式的核心调度模块。

- `PluginManager.swift`：负责管理所有插件，包括插件的注册、状态维护、统一调度，采用单例模式，确保全局唯一实例。
- `PluginLoader.swift`：仅负责单个插件的加载与初始化，每次加载一个插件，采用单例模式，保证加载过程一致性。
- `PluginExecutor.swift`：插件执行环境，支持 JS/Swift 等多语言插件。
- `PluginConfigManager.swift`：插件配置读写。
- `PluginPermissionManager.swift`：权限校验与管理。

插件模型架构说明：

1. `Plugin.swift` —— 插件内容与元信息
   - 负责描述插件的基本信息（如名称、版本、命令、描述、权限等），并包含插件脚本、配置、入口等。
   - 通过 `PluginManifest` 结构体解析 manifest.yaml，支持权限声明、界面元数据、帮助文本等。
   - 每个插件对象都拥有唯一 id、脚本内容、有效配置、权限列表等，是插件管理和运行的核心数据结构。

2. `PluginInstance.swift` —— 插件运行时实例
   - 管理插件激活后的运行时状态，包括 JSContext 环境、API 管理器、启用状态等。
   - 每个激活的插件对应一个实例，负责资源初始化、上下文注入、API绑定、资源释放等。
   - 支持插件的动态启用/禁用，保证插件运行的隔离性和安全性。

3. `PluginItem.swift` —— 插件结果项与展示
   - 实现 `DisplayableItem` 协议，作为插件模式下的统一结果项。
   - 支持标题、副标题、图标（SF Symbol/base64）、动作标识等，便于主程序统一展示和交互。
   - 通过 `PluginResult` 结构体支持批量结果、分页、总数等高级功能。

4. `PluginError.swift` —— 插件错误类型
   - 定义插件相关的错误枚举，包括清单无效、主文件缺失、加载失败、执行失败、配置错误、依赖缺失、权限拒绝、超时、API无效、脚本错误等。
   - 每种错误类型都支持详细描述，便于主程序和插件开发者定位和处理问题。
   - 错误类型贯穿插件加载、执行、API调用等各个环节，保证插件系统的健壮性和可维护性。

整体架构关系：
 - `Plugin` 负责插件的静态描述和数据，`PluginInstance` 管理插件的运行时资源和状态，`PluginItem` 负责插件结果的统一展示，`PluginError` 负责插件相关的错误处理。
 - 通过这些模型文件，主程序实现了插件的声明、加载、运行、交互、错误处理等完整生命周期管理。

# 六、插件 API 设计

- API 通过 `APIManager.swift` 统一调度，支持异步调用。
- 主要接口包括：数据获取、事件监听、UI交互、系统操作等。
- API 支持扩展，便于后续增加新功能。

# 七、插件视图与交互

- 插件相关 UI 组件在 `Views/` 下实现，如 `PluginItemRowView.swift`、`PluginModeView.swift`。
- 支持插件自定义部分界面，主程序负责统一风格和安全性。

# 八、插件权限与安全

- 插件权限

插件通过 API 粒度声明和限制权限，主程序根据插件 manifest 文件中的权限声明进行审核和授权。每个敏感 API 都需在 manifest.yaml 中显式声明，未授权的 API 调用将被拒绝。

常见敏感 API 及权限示例：

- `readFile`：读取本地文件内容，需声明 `file.read` 权限。
- `writeFile`：写入本地文件，需声明 `file.write` 权限。
- `readClipboard`：读取剪贴板内容，需声明 `clipboard.read` 权限。
- `writeClipboard`：写入剪贴板，需声明 `clipboard.write` 权限。
- `networkRequest`：访问网络，需声明 `network` 权限。
- `getAppList`：获取本机应用列表，需声明 `app.list` 权限。
- 其他自定义 API 需按功能声明相应权限。

权限声明方式：

```yaml
permissions:
  - file.read
  - clipboard.read
  - network
```

主程序在插件加载时校验权限声明，敏感操作需用户确认授权。所有 API 调用均通过权限管理器（`PluginPermissionManager.swift`）进行校验，未授权时返回错误或弹窗提示。

插件运行环境采用沙箱隔离，限制访问范围，防止越权和恶意行为。

# 九、插件开发流程

1. 新建插件目录，编写 `manifest.yaml`、`main.js`、`config.yaml`。
2. 实现必要 API，测试功能。
3. 提交插件，主程序自动加载并校验。
4. 用户可在设置界面启用/禁用插件。

# 十、后续规划

- 支持插件市场，便于分发和管理。
- 增加更多 API 和系统集成能力。
- 完善插件文档和开发者工具。
