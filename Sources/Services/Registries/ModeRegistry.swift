import Foundation

/// 统一的 mode controller 注册中心。
///
/// 每个 controller 的 `.shared` 通过 `register(_:)` 自注册,
/// 一次调用同时填充 mode 索引、类型索引,并对接 `CommandRegistry` 的命令前缀。
///
/// 视图层不再依赖 `LauncherViewModel` 的 typed accessor,
/// 通过 `ModeRegistry.shared[ModeController.self]` 按类型取;
/// `LauncherViewModel` 通过 `ModeRegistry.shared.controller(for:)` 按 mode 路由。
@MainActor
final class ModeRegistry {
    static let shared = ModeRegistry()

    private var byMode: [LauncherMode: any ModeStateController] = [:]
    private var byType: [ObjectIdentifier: any ModeStateController] = [:]

    private init() {}

    /// 在应用启动时调用一次,触发所有内置 controller 的 `.shared`,
    /// 进而通过 `register(_:)` 完成 mode 索引、类型索引、CommandPrefix 三处注册。
    ///
    /// Swift 没有原生类型发现机制,eager 注册必须显式枚举 controller 类型。
    /// 这是当前设计中**唯一**显式列举 controller 的中心点:
    /// 之前在 `LauncherViewModel` 里的 typed accessor + 中心数组已删除,
    /// 但这一份清单无法去除——任何 controller 必须先被访问才能 self-register。
    ///
    /// 新增一个 controller 需要 1 个新文件 + 在此处加 1 行。
    func bootstrap() {
        _ = LaunchModeController.shared
        _ = KillModeController.shared
        _ = FileModeController.shared
        _ = SearchModeController.shared
        _ = WebModeController.shared
        _ = ClipModeController.shared
        _ = TerminalModeController.shared
        _ = PluginModeController.shared
        _ = KeywordModeController.shared
    }

    /// 一站式注册:mode 索引 + 类型索引 + CommandRegistry。
    @discardableResult
    func register<T: ModeStateController>(_ controller: T) -> T {
        byMode[controller.mode] = controller
        byType[ObjectIdentifier(T.self)] = controller
        CommandRegistry.shared.register(controller)
        return controller
    }

    /// 按 mode 取(用于 LauncherViewModel 的 activeController 路由)。
    func controller(for mode: LauncherMode) -> (any ModeStateController)? {
        byMode[mode]
    }

    /// 按类型取(用于视图想要某个具体 controller 的场景)。
    subscript<T: ModeStateController>(_: T.Type) -> T? {
        byType[ObjectIdentifier(T.self)] as? T
    }
}
