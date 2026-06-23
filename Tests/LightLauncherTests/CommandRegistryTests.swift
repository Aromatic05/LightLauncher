import Combine
import XCTest
@testable import LightLauncher

@MainActor
final class CommandRegistryTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        CommandRegistry.shared.unregister(prefix: TestDynamicModeController.shared.prefix!)
    }

    override func tearDown() async throws {
        CommandRegistry.shared.unregister(prefix: TestDynamicModeController.shared.prefix!)
        try await super.tearDown()
    }

    func testRegister_usesStableCommandDisplayNameInsteadOfDynamicDisplayName() {
        let controller = TestDynamicModeController.shared
        controller.dynamicDisplayName = "Changed at Runtime"

        CommandRegistry.shared.register(controller)

        let record = CommandRegistry.shared.findCommand(for: controller.prefix!)

        XCTAssertEqual(record?.record.displayName, controller.commandDisplayName)
        XCTAssertNotEqual(record?.record.displayName, controller.displayName)
    }
}

@MainActor
private final class TestDynamicModeController: ModeStateController {
    static let shared = TestDynamicModeController()

    let mode: LauncherMode = .search
    let prefix: String? = "/__dynamic_command_registry_test__"
    var displayName: String { dynamicDisplayName }
    let commandDisplayName: String = "Stable Search Command"
    let iconName: String = "testtube.2"
    let placeholder: String = "placeholder"
    let modeDescription: String? = "description"
    var displayableItems: [any DisplayableItem] = []
    let dataDidChange = PassthroughSubject<Void, Never>()

    var dynamicDisplayName = "Initial Dynamic Name"

    private init() {}

    func handleInput(arguments: String) {}
    func cleanup() {}
}
