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
